#!/bin/bash


#This script is to compile a collection of github repo links to check if they are compilable. 

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
[ -f "$file" ] || echo "Usage: file.txt" || exit 0;
#make an ouput dir 
mkdir -p output
rootpath=$(pwd)
outdir=$(realpath output)
rm -rf "$outdir"/*

#Loop through each link: May cause error if wrapped with "" 
while read -r repo; do
    
    dirName="$(basename -- "$repo")"
    cd "$outdir" || exit 0
    mkdir "$outdir"/"$dirName"
    echo "[-------------Cloning $repo-------------]"
    git clone "$repo" "$dirName" 
    cd "$dirName" || exit 0
    if [ -f "build.gradle" ] 
    then
        echo "[-------------Build file exists-------------]"
        #</dev/null   
        gradlew_output=$(./gradlew compileJava </dev/null 2>"$outdir"/"$dirName".log ); gradlew_return_code=$? 
        if [ $gradlew_return_code != 0 ] #test this on build that failes
        then 
            echo "[-------------Grade failed with exit status $gradlew_return_code-------------]"
            pwd
            cd "$outdir" | exit 0
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
done < "$file"
echo "[-------------Completed-------------]"
rm -rf output/*