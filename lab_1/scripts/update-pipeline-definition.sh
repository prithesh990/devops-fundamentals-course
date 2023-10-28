#!/bin/bash

# To execute this script, you need to add execute permissions:
# chmod +x update-pipeline-definition.sh

set -e # stop on first error

if ! [ -x "$(command -v jq)" ]; then
  echo 'Error: jq is not installed. Install it using:
    - Debian/Ubuntu: sudo apt-get install jq
    - MacOS: brew install jq' >&2
  exit 1
fi

# add your configuration here

FILE="./pipeline.json"
DATE=$(date +"%Y%m%d%H%M%S")
OUTPUT_FILE="pipeline-${DATE}.json"
BRANCH="main"
OWNER=""
REPO=""
POLL_FOR_SOURCE_CHANGES="false"
BUILD_CONFIGURATION=""



read -p "Please, enter the pipeline’s definitions file path (default: pipeline.json):" USER_FILE 
if [ -n "$USER_FILE" ]; then
   FILE="$USER_FILE"
fi

read -p "Which BUILD_CONFIGURATION name are you going to use (default: “”):" USER_BUILD_CONFIGURATION
if [ -n "$USER_BUILD_CONFIGURATION" ]; then
   BUILD_CONFIGURATION="$USER_BUILD_CONFIGURATION"
fi 

read -p "Enter a GitHub owner/account (ex:boale):" USER_OWNER
if [ -n "$USER_OWNER" ]; then
   OWNER="$USER_OWNER"
fi 

read -p "Enter a GitHub repository name (ex: shop-angular-cloudfront):" USER_REPO
if [ -n "$USER_REPO" ]; then
   REPO="$USER_REPO"
fi
 
read -p "Enter a GitHub branch name (default: $BRANCH): feat/cicd-lab:" USER_BRANCH
if [ -n "$USER_BRANCH" ]; then
   BRANCH="$USER_BRANCH"
fi

read -p "Do you want the pipeline to poll for changes (false/true) (default:$POLL_FOR_SOURCE_CHANGES)?:" USER_POLL_FOR_SOURCE_CHANGES
if [ -n "$USER_POLL_FOR_SOURCE_CHANGES" ]; then
   POLL_FOR_SOURCE_CHANGES="$USER_POLL_FOR_SOURCE_CHANGES"
fi


echo "here " $FILE $OWNER

# Check if the necessary properties are present
if jq -e '.pipeline' "$FILE" > /dev/null 2>&1; then
    echo "Pipeline property exists"
else
    echo "Pipeline property does not exist"
    exit 1
fi

if jq -e '.metadata' "$FILE" > /dev/null 2>&1; then
    echo "Metadata property exists"
else
    echo "Metadata property does not exist"
    exit 1
fi

# Remove metadata, increment version
jq 'del(.metadata) | .pipeline.version += 1' "$FILE" > $OUTPUT_FILE

# Apply additional parameters
if [ -n "$BRANCH" ]; then
    jq --arg BRANCH "$BRANCH" '.pipeline.stages[] | select(.name=="Source") | .actions[] | select(.name=="Source") | .configuration.Branch = $BRANCH' $OUTPUT_FILE > tmp.json && mv tmp.json $OUTPUT_FILE
fi

if [ -n "$OWNER" ]; then
    jq --arg OWNER "$OWNER" '.pipeline.stages[] | select(.name=="Source") | .actions[] | select(.name=="Source") | .configuration.Owner = $OWNER' $OUTPUT_FILE > tmp.json && mv tmp.json $OUTPUT_FILE
fi

if [ -n "$REPO" ]; then
    jq --arg REPO "$REPO" '.pipeline.stages[] | select(.name=="Source") | .actions[] | select(.name=="Source") | .configuration.Repo = $REPO' $OUTPUT_FILE > tmp.json && mv tmp.json $OUTPUT_FILE
fi

if [ -n "$POLL_FOR_SOURCE_CHANGES" ]; then
    jq --arg POLL_FOR_SOURCE_CHANGES "$POLL_FOR_SOURCE_CHANGES" '.pipeline.stages[] | select(.name=="Source") | .actions[] | select(.name=="Source") |.configuration.PollForSourceChanges = $POLL_FOR_SOURCE_CHANGES' $OUTPUT_FILE > tmp.json && mv tmp.json $OUTPUT_FILE
fi

if [ -n "$BUILD_CONFIGURATION" ]; then
    jq --arg BUILD_CONFIGURATION "$BUILD_CONFIGURATION" '.pipeline.stages[] | .actions[].configuration.EnvironmentVariables = "[{\"name\":\"BUILD_CONFIGURATION\",\"value\": $BUILD_CONFIGURATION, \"type\":\"PLAINTEXT\"}]"' $OUTPUT_FILE > tmp.json && mv tmp.json $OUTPUT_FILE
fi

echo "Pipeline JSON successfully updated and saved as $OUTPUT_FILE"
