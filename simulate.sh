#!/usr/bin/env bash
set -euo pipefail

path=$(mktemp -d -t simulate-XXXXX -p .)

echo "Creating a new repository in $path"
git init "$path"

cd "$path"
cp ../update_workflows.sh .

./update_workflows.sh github-only --force .

eche "Creating the word list file"

touch workflow.txt
