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

(
  cd "$path"
  git remote add origin "../$path_origin"
  git fetch origin main
  git checkout main
)

./update_workflows.sh terraform_module --force --dry-run "$path"

echo "Creating the word list file"

export LC_ALL='C'

# Make a list of every misspelled word without any custom dictionaries and configuration file
cd "$path"

CSPELL_CONFIGURATION_FILE=".config/cspell.json"
DICTIONARIES_PATH=".config/dictionaries"

cp "$CSPELL_CONFIGURATION_FILE" "${CSPELL_CONFIGURATION_FILE}.temp"

jq 'del(.dictionaryDefinitions)' "${CSPELL_CONFIGURATION_FILE}.temp" | \
  jq 'del(.dictionaries)' > "$CSPELL_CONFIGURATION_FILE"

# renovate: datasource=npm depName=@cspell/dict-cspell-bundle
cspell_dict_version="1.0.30"
npm i -D @cspell/dict-cspell-bundle@${cspell_dict_version}

# renovate: datasource=github-releases depName=streetsidesoftware/cspell
cspell_version="8.17.3"
npx cspell@${cspell_version} . -c "$CSPELL_CONFIGURATION_FILE" --dot --no-progress --no-summary --unique --words-only \
  --no-exit-code --exclude "$DICTIONARIES_PATH/**" | sed 's/.*/\L&/g' | sort --ignore-case --unique > ../.config/dictionaries/workflow.txt

mv "${CSPELL_CONFIGURATION_FILE}.temp" "$CSPELL_CONFIGURATION_FILE"

echo "Dictionary workflow.txt updated in your branch. Please review and commit the changes."
