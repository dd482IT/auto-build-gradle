#!/bin/bash


# This script is to compile a collection of github repo links to check if they are compilable. 
# First argument is the file containing a link to each repo you want to test build
# This works on gradle, maven and (still needs testing) ant projects. 
# Usage: ./auto-compiler.sh myfile


if ! command -v git &> /dev/null
then
    echo "git could not be found"
    exit 0
fi 

if [ -z ${1} ]; then echo "File is required" && exit 0;fi
file=$1 #file argument

linksCount=$(wc -l $file)
iteration=0
successful=0 
failed=0


#check if argument file exists
[ -f "$file" ] || echo "Usage: file.txt"
#make an ouput dir 
mkdir -p output
rootpath=$(pwd)
outdir=$(realpath output)
rm -rf "$outdir"/*

#Loop through each link: May cause error if wrapped with 
while read -r repo; do
    echo "[Current Link $repo]"
# Extract name of project
    dirName="$(basename -- "$repo")"
# Change into workspace and make project directory
    cd "$outdir" 
    mkdir "$dirName"
# Begin cloning project
    echo "[Cloning ["$repo"]]"
    git clone "$repo" "$dirName" 
# Change directory into project 
# Check for build exec or just build
    cd "$dirName" 
    iteration=$((iteration+1))
    if [ -f "gradlew" ];
    then
        echo "[Gradlew file Exists]"
        #</dev/null   
        gradlew_output=$(./gradlew compileJava </dev/null 2>"$outdir"/"$dirName".log ); gradlew_return_code=$? 
        if [ $gradlew_return_code != 0 ] #test this on build that failes
        then 
            echo "[Grade failed with exit status $gradlew_return_code]"
            failed=$((failed+1))
            cd "$outdir" | exit 1
            rm -rf "$dirName"
            continue    
        fi
        echo "$repo" >> "$rootpath"/buildable.txt
        successful=$((successful+1))
    elif [ -f "pom.xml" ];
    then
        echo "[Pom.xml file Exists]"
        maven_output=$(mvn compile); maven_return_code=$?
        if [ $maven_return_code != 0 ] #test this on build that failes
        then 
            echo "[Maven failed with exit status $maven_return_code]"
            failed=$((failed+1))
            cd "$outdir" || exit 1
            rm -rf "$dirName"
            continue    
        fi
        echo "$repo" >> "$rootpath"/buildable.txt
        successful=$((successful+1))
        "[Progress:$iteration/$linksCount successful:$successful failed:$failed]"
    elif [ -f "build.xml" ];
    then
        echo "[Build.xml file Exists]"
        maven_output=$(ant compile); ant_return_code=$?
        if [ $ant_return_code != 0 ] #test this on build that failes
        then 
            echo "[Ant failed with exit status $ant_return_code]"
            failed=$((failed+1))
            cd "$outdir" || exit 1
            rm -rf "$dirName"
            continue    
        fi
        echo "$repo" >> "$rootpath"/buildable.txt
        successful=$((successful+1))
        "[Progress:$iteration/$linksCount successful:$successful failed:$failed]"
    else
        echo "[Build file does not exist]"
        cd "$outdir" | exit
        echo "[Attempting to remove clone]"
        rm -rf "$dirName" && echo "[Deleted $dirName]"
        failed=$((failed+1))
        "[Progress:$iteration/$linksCount successful:$successful failed:$failed]"
    fi
    #exit 0 # This is for testing a single project at a time. Remove this to use entire file.   
done < "$file"
echo "[Progress:$iteration/$linksCount successful:$successful failed:$failed]"
