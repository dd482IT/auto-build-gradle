#!/bin/bash


# This script is to compile a collection of github repo links to check if they are compilable. 
# First argument is the file containing a link to each repo you want to test build
# This works on gradle, maven and (still needs testing) ant projects. 
# Usage: ./auto-compiler.sh myfile

# check if git is installed
if ! command -v git &> /dev/null
then
    echo "git could not be found"
    exit 0
fi 

# debugging: time tracking
# check if file was passed
if [ -z "${1}" ]; then echo "File is required" && exit 0;fi
file=$(readlink -f $1) #file argument

# Delete previous build file if present
if [ -f "buildable.txt" ]; 
then 
    rm buildable.txt
fi
# Create new text list
touch buildable.txt
buildable=$(readlink -f buildable.txt)
# Staistics variables
linksCount=$(cat "$file" | wc -l)
iteration=0
successful=0 
failed=0
missingBuildFile=0
#make an ouput dir to hold the cloned repos
mkdir -p output && cd output && outdir=$(pwd)
#Loop through each link: May cause error if wrapped with 
while read -r repo; do
    echo "[Current Link $repo]"
# Extract name of project
    dirName="$(basename -- "$repo")"
# Change into workspace and make project directory
    cd $outdir
    mkdir "$dirName"
# Begin cloning project
    git clone "$repo" "$dirName"
# Change directory into project 
# Check for build exec or just build
    cd "$dirName" 
    iteration=$((iteration+1))
    if [ -f "gradlew" ];
    then
        echo "[Gradlew file Exists]"
        gradlew_output=$(./gradlew compileJava </dev/null 2>"$outdir"/"$dirName".log ); gradlew_return_code=$? 
        if [ $gradlew_return_code != 0 ] #test this on build that failes
        then 
            failed=$((failed+1))
            cd "$outdir" | exit 1
        else 
            echo "$repo" >> $buildable
            successful=$((successful+1))
        fi
        rm -rf "$dirName"
        continue 
    elif [ -f "pom.xml" ];
    then
        echo "[Pom.xml file Exists]"
        maven_output=$(mvn compile); maven_return_code=$?
        if [ $maven_return_code != 0 ] #test this on build that failes
        then 
            failed=$((failed+1))
            cd "$outdir" || exit 1
        else
            echo "$repo" >> $buildable
            successful=$((successful+1))    
        fi
        rm -rf "$dirName"
        continue
    elif [ -f "build.xml" ];
    then
        echo "[Build.xml file Exists]"
        maven_output=$(ant compile); ant_return_code=$?
        if [ $ant_return_code != 0 ] #test this on build that failes
        then 
            failed=$((failed+1))
            cd "$outdir" || exit 1
        else 
            echo "$repo" >> $buildable
            successful=$((successful+1))
        fi
        rm -rf "$dirName"
        continue
    else
        cd "$outdir" | exit
        rm -rf "$dirName" && echo "[Deleted $dirName]"
        missingBuildFile=$((missingBuildFile+1))
    fi
    echo "[Progress:$iteration/$linksCount successful:$successful failed:$failed]"
    #exit 0 # This is for testing a single project at a time. Remove this to use entire file.   
done < "$file"
rm -r $outdir
echo "[Progress:$iteration/$linksCount successful:$successful failed:$failed Missing Build:$missingBuildFile]"
