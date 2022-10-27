#!/bin/bash


# This script is to compile a collection of github repo links to check if they are compilable. 
# First argument is the file containing a link to each repo you want to test build
# Usage: ./auto-compiler.sh myfile

#To do:
#-Check the cloned directory recursively for a "build.gradle" 
#-Find a way to redirect any failed builds to standard error. *currently outputs to a <repo>.log file 
#-Modify script to use pop instead of cd

file=$1 #file argument
if ! command -v git &> /dev/null
then
    echo "git could not be found"
    exit 
fi 
#check if argument file exists
[ -f "$file" ] || echo "Usage: file.txt"
#make an ouput dir 
mkdir -p output
rootpath=$(pwd)
outdir=$(realpath output)
rm -rf "$outdir"/*

#Loop through each link: May cause error if wrapped with "" 
while read -r repo; do

    dirName="$(basename -- "$repo")"
    cd "$outdir" || echo "[-------No Out Dir-------]"
    mkdir "$outdir"/"$dirName"
    echo "[-------------Cloning ["$repo"]-------------]"
    git clone "$repo" "$dirName" 
    cd "$dirName" || echo "[-------No Repo Dir-------]" 
    if [ -f "gradlew" ];
    then
        echo "[-------------Gradlew file Exists-------------]"
        #</dev/null   
        gradlew_output=$(./gradlew compileJava </dev/null 2>"$outdir"/"$dirName".log ); gradlew_return_code=$? 
        if [ $gradlew_return_code != 0 ] #test this on build that failes
        then 
            echo "[-------------Grade failed with exit status $gradlew_return_code-------------]"
            pwd
            cd "$outdir" | exit 1
            rm -rf "$dirName"
            continue    
        fi
        echo "$repo" >> "$rootpath"/buildable.txt
    elif [ -f "pom.xml" ];
    then
        echo "[-------------Pom.xml file Exists-------------]"
        maven_output=$(mvn compile); maven_return_code=$?
        if [ $maven_return_code != 0 ] #test this on build that failes
        then 
            echo "[-------------Maven failed with exit status $maven_return_code-------------]"
            pwd
            cd "$outdir" || exit 1
            rm -rf "$dirName"
            continue    
        fi
        echo "$repo" >> "$rootpath"/buildable.txt
    else
        echo "[-------------Build file does not exist-------------]"
        cd "$outdir" | exit
        echo "[-------------Attempting to remove clone-------------]"
        rm -rf "$dirName" && echo "[-------------Deleted $dirName-------------]"
    fi
    exit 0 # This is for testing a single project at a time. Remove this to use entire file. 
done < "$file"
echo "[-------------Completed-------------]"
rm -rf output/*