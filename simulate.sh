#!/usr/bin/env bash
set -euo pipefail

function spell_check() {
  files_to_check="$1"
  unknown_words_file="$2"

  cp "$CSPELL_CONFIGURATION_FILE" "${CSPELL_CONFIGURATION_FILE}.temp"

  jq 'del(.dictionaryDefinitions)' "${CSPELL_CONFIGURATION_FILE}.temp" | \
    jq 'del(.dictionaries)' > "$CSPELL_CONFIGURATION_FILE"

  # renovate: datasource=npm depName=@cspell/dict-cspell-bundle
  cspell_dict_version="1.0.30"
  npm i -D @cspell/dict-cspell-bundle@${cspell_dict_version}

  # renovate: datasource=github-releases depName=streetsidesoftware/cspell
  cspell_version="8.17.3"
  npx cspell@${cspell_version} "$files_to_check" -c "$CSPELL_CONFIGURATION_FILE" --dot --no-progress --no-summary --unique --words-only \
    --no-exit-code --exclude "$DICTIONARIES_PATH/**" | sed 's/.*/\L&/g' | sort --ignore-case --unique > "$unknown_words_file"

  mv "${CSPELL_CONFIGURATION_FILE}.temp" "$CSPELL_CONFIGURATION_FILE"
}

CSPELL_CONFIGURATION_FILE=".config/cspell.json"
DICTIONARIES_PATH=".config/dictionaries"

for project_type in terraform_module docker python maven github-only; do
  echo "Updating the $project_type project type"

  path=$(mktemp -d -t simulate-${project_type}-XXXXX -p .)
  path_origin=$(mktemp -d -t simulate-origin-${project_type}-XXXXX -p .)

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

  ./update_workflows.sh "$project_type" --force --dry-run "$path"

  # create the dictionary files for the specific project type
  dictionary_file="../.config/dictionaries/${project_type}.txt"
  if [ "$project_type" = "github-only" ]; then
    dictionary_file="../.config/dictionaries/simple.txt"
  elif [ "$project_type" = "terraform_module" ]; then
    dictionary_file="../.config/dictionaries/terraform-module.txt"
  fi

  (
    cd "$path"

    # clear the dictionary file and run the spell check
    true > "$dictionary_file" && spell_check . "$dictionary_file"
  )
done

echo "Dictionaries updated in your branch. Please review and commit the changes."
