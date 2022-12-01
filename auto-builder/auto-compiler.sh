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
    MAVEN_BUILDFILE="pom.xml"
    GRADLE_BUILDFILE="build.gradle"
    ANT_BUILDFILE="build.xml"
    

    check_build () {
        find -name $1 > .build_files.txt ; BUILDFILES=".build_files.txt"
        FILECOUNT=$(wc -l $BUILDFILES | sed 's/\s.*$//')
        return $FILECOUNT
    }
    
    if check_build MAVEN_BUILDFILE -gt 0 
    then
        echo "This is a maven build"
        # Lets starting looping through the list of build files we found
        while read -r BUILDFILE; do
            # Here we are checking for each build file to see if it is using checkerframework 
            CHECK=$(rg "org.checkerframework" $BUILDFILE)
            # If check exists for our string query, lets work with it, otherwise, continue to the next file 
            if [ -z $CHECK ]
            then 
                cd # cd to the path of the file 
                GRADLEW="gradlew"#somtimes, gradlew does not have permissions 
                if [ -z $GRADLEW ]
                then 
                    chmod +x $gradlew # somtimes the build files do not have privleges to be executed
                    # We assume at this point we that, there is a gradlew exec. Need to handle somehow
                    gradlew_output=$(./gradlew compileJava </dev/null 2>"$outdir"/"$dirName".log ); gradlew_return_code=$? 
                    if [ $gradlew_return_code != 0 ] 
                    then 
                        failed=$((failed+1))
                    else 
                        echo "$repo" >> $buildable
                        successful=$((successful+1))
                    fi
                else
                    # What should we do if a gradlew exec does not exist? Move onto the next pom.xml I suppose. 
                fi
            else 
                continue # Lets move onto the next build file in the list
            fi
            # cd to the path of that build file 
            # attempt to build in that specific directory
        done < $BUILDFILES
    else 
        rm $BUILDFILES
    fi  
    exit 0   
done < "$file"
rm -r $outdir
echo "[Progress:$iteration/$linksCount successful:$successful failed:$failed Missing Build:$missingBuildFile]"
