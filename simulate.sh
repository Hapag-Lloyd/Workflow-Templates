#!/usr/bin/env bash
set -euo pipefail

DICTIONARIES_PATH=".config/dictionaries"

path=$(mktemp -d -t simulate-XXXXX -p .)
path_origin=$(mktemp -d -t simulate-origin-XXXXX -p .)

echo "Creating the remote repository in $path_origin"
(
  git init --initial-branch main "$path_origin"

  cd "$path_origin"
  touch README.md
  git add README.md
  git commit -m "xxx"
)

echo "Creating a new repository in $path"
git init --initial-branch main "$path"

cd "$path"
git remote add origin "../$path_origin"
git fetch origin main
git checkout main

cp ../update_workflows.sh .

./update_workflows.sh python --force . --dry-run --local-workflow-path ../
# script is now located in .github/
rm update_workflows.sh

echo "Creating the word list file"

# don't use the cspell.json file to get the list of misspelled words we need to add to the dictionary
mv .config/cspell.json .config/cspell.json.temp

# renovate: datasource=github-releases depName=streetsidesoftware/cspell
cspell_version="v8.17.1"
npx cspell@${cspell_version:1} . --dot --no-progress --no-summary --unique --words-only --no-exit-code --exclude ".git/**" --exclude ".idea/**" --exclude "$DICTIONARIES_PATH/**" | sort --ignore-case --unique > ../.config/dictionaries/workflow.txt

mv .config/cspell.json.temp .config/cspell.json

echo "Dictionary workflow.txt updated in your branch. Please review and commit the changes."
