#!/usr/bin/env bash
set -euo pipefail

destination_path=""
repository_type=""
release_type="auto"

function ensure_prerequisites_or_exit() {
  if ! command -v yq &> /dev/null; then
    echo "yq is not installed. https://github.com/mikefarah/yq"
    exit 1
  fi

  if ! command -v gh &> /dev/null; then
    echo "gh is not installed. Please install it from https://cli.github.com/"
    exit 1
  fi
}

function ensure_repo_preconditions_or_exit() {
  # ensure main branch
  if [ "$(git branch --show-current)" != "main" ]; then
    echo "The current branch is not main. Please switch to the main branch."
    exit 1
  fi

  # ensure a clean working directory
  if [ -n "$(git status --porcelain)" ]; then
    echo "The working directory is not clean. Please use a clean copy so no unintended changes are merged."
    exit 1
  fi
}

function show_help_and_exit() {
  echo "Usage: $0 <path-to-new-repo> <repository-type> --release-type auto|manual"
  echo "repository-type: docker, github-only, maven, terraform_module"
  echo "release-type: (optional)"
  echo "  auto: the release will be triggered automatically on a push to the default branch"
  echo "  manual: the release will be triggered manually via separate PR, which is created automatically"

  exit 1
}

function create_commit_and_pr() {
  local repo_directory=$1

  cd "$repo_directory" || exit 7

  git checkout -b update-workflows

  git add .
  git commit -m "update workflows to latest version"
  git push --set-upstream origin update-workflows

  body=$(cat <<EOF
# Description

This PR updates all workflows to the latest version.

# Verification

Done by the workflows in this feature branch, except for the release workflow.
EOF
  )

  gh pr create --title "ci(deps): update workflows to latest version" --body "$body" --base main
  gh pr view --web
}

function ensure_and_set_parameters_or_exit() {
  POSITIONAL_ARGS=()

  while [[ $# -gt 0 ]]; do
    case $1 in
      --release-type)
        release_type=$2
        shift
        shift
        ;;
      --*|-*)
        echo "Unknown option $1"
        show_help_and_exit
        ;;
      *)
        POSITIONAL_ARGS+=("$1") # save positional arg
        shift # past argument
        ;;
    esac
  done

  set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

  # check for 3 mandatory positional arguments
  if [ "${#POSITIONAL_ARGS[@]}" -ne 2 ]; then
    show_help_and_exit
  fi

  destination_path=$1
  repository_type=$2

  # check if the directory exists
  if [ ! -d "$destination_path" ]; then
    echo "The repository $destination_path does not exist."
    exit 2
  fi

  # check for correct type: docker, github-only, maven, terraform_module
  if [ "$repository_type" != "github-only" ] && [ "$repository_type" != "maven" ] && [ "$repository_type" != "terraform_module" ] && [ "$repository_type" != "docker" ]; then
    echo "The repository type $repository_type is not supported."
    show_help_and_exit
  fi

  if [ "$repository_type" != "terraform_module" ] && [ "$release_type" == "manual" ]; then
    echo "The release type 'manual' is only supported for terraform_module repositories."
    show_help_and_exit
  fi
}

function setup_cspell() {
  # init the dictionaries
  if [ ! -d "$destination_path/.config/dictionaries" ]; then
    cp -pr .config/dictionaries "$destination_path/.config/"
  fi
  # unknown words for copied workflows
  cp -p ".config/dictionaries/workflow.txt" "$destination_path/.config/dictionaries/"

  # the dictionaries for the specific repository types
  cp -p ".config/dictionaries/maven.txt" "$destination_path/.config/dictionaries/"
  cp -p ".config/dictionaries/terraform-module.txt" "$destination_path/.config/dictionaries/"
  cp -p ".config/dictionaries/docker.txt" "$destination_path/.config/dictionaries/"
  cp -p ".config/dictionaries/simple.txt" "$destination_path/.config/dictionaries/"
  cp -p ".config/dictionaries/python.txt" "$destination_path/.config/dictionaries/"

  # project dictionary for the rest, do not overwrite
  if [ ! -f "$destination_path/.config/dictionaries/project.txt" ]; then
    touch "$destination_path/.config/dictionaries/project.txt"
  fi

  # fix the "addWords" setting needed for some IDEs
  jq 'del(.dictionaryDefinitions[] | select(.addWords) | .addWords)' "$destination_path/.config/cspell.json" > "$destination_path/.config/cspell.json.tmp"

  repository_name=$(basename "$destination_path")

  if [ "$repository_name" == "Repository-Template-Docker" ]; then
    jq '(.dictionaryDefinitions[] | select(.name == "docker")).addWords |= true' "$destination_path/.config/cspell.json.tmp" > "$destination_path/.config/cspell.json"
  elif [ "$repository_name" == "Repository-Template-Maven" ]; then
    jq '(.dictionaryDefinitions[] | select(.name == "maven")).addWords |= true' "$destination_path/.config/cspell.json.tmp" > "$destination_path/.config/cspell.json"
  elif [ "$repository_name" == "Repository-Template-Terraform-Module" ]; then
    jq '(.dictionaryDefinitions[] | select(.name == "terraform-module")).addWords |= true' "$destination_path/.config/cspell.json.tmp" > "$destination_path/.config/cspell.json"
  elif [ "$repository_name" == "Repository-Template-Simple" ]; then
    jq '(.dictionaryDefinitions[] | select(.name == "simple")).addWords |= true' "$destination_path/.config/cspell.json.tmp" > "$destination_path/.config/cspell.json"
  elif [ "$repository_name" == "Repository-Template-Python" ]; then
    jq '(.dictionaryDefinitions[] | select(.name == "python")).addWords |= true' "$destination_path/.config/cspell.json.tmp" > "$destination_path/.config/cspell.json"
  else
    jq '(.dictionaryDefinitions[] | select(.name == "project")).addWords |= true' "$destination_path/.config/cspell.json.tmp" > "$destination_path/.config/cspell.json"
  fi

  rm "$destination_path/.config/cspell.json.tmp"
}

ensure_prerequisites_or_exit
ensure_repo_preconditions_or_exit
ensure_and_set_parameters_or_exit "$@"

echo "Updating the workflows in $destination_path"

# enable nullglob to prevent errors when no files are found
shopt -s nullglob

# basic setup for all types
mkdir -p "$destination_path/.github/workflows/scripts"
cp .github/workflows/default_* "$destination_path/.github/workflows"
cp .github/workflows/scripts/* "$destination_path/.github/workflows/scripts/"

cp .github/pull_request_template.md "$destination_path/.github/"
cp .github/renovate.json5 "$destination_path/.github/"

# move the update-workflows.sh script to the correct location (from older releases)
if [ -f "$destination_path/update-workflows.sh" ]; then
  git mv -f "$destination_path/update-workflows.sh" "$destination_path/.github/update_workflows.sh"
fi

mkdir -p "$destination_path/.config"
# copy fails if a directory is hit. dictionaries/ is handled in the setup_cspell function
cp -p .config/*.* "$destination_path/.config/"

setup_cspell

# we do not have special files for simple GitHub projects, this is handled by the default setup
if [ "$repository_type" != "github-only" ]; then
  cp ".github/workflows/${repository_type}"_* "$destination_path/.github/workflows/"
fi

# setup the release workflow
if [ "$release_type" == "manual" ]; then
  rm "$destination_path/.github/workflows/"default*release*_callable.yml
fi

#
# Fix the "on" clause in the workflow files, remove all jobs and set a reference to this repository
#

# iterate over each file in the directory
for file in "$destination_path"/.github/workflows/*.yml
do
  base_name=$(basename "$file")

  # remove everything else as we will reference the file in this repository
  sed -i '/jobs:/,$d' "$file"

  # add a reference to this repository which holds the workflow
  commit_sha=$(git rev-parse HEAD)
  tag=$(git describe --tags "$(git rev-list --tags --max-count=1)" || true)

  file_to_include="uses: Hapag-Lloyd/Workflow-Templates/.github/workflows/$base_name@$commit_sha # $tag"

  # 128 = 132 - 4 spaces (indentation)
  if [ ${#file_to_include} -gt 128 ]; then
    file_to_include="# yamllint disable-line rule:line-length"$'\n'"    $file_to_include"
  fi

  cat >> "$file" <<-EOF
jobs:
  default:
    $file_to_include
    secrets: inherit
EOF

  # add TODOs for the parameters of the workflow
  # false positive, variable is quoted
  # shellcheck disable=SC2086
  if [ "$(yq '.on["workflow_call"] | select(.inputs) != null' $file)" == "true" ]; then
    cp "$file" "$file.bak"
    echo "    with:" >> "$file"

    yq '.on.workflow_call.inputs | keys | .[]' "$file".bak | while read -r input; do
      type=$(yq ".on.workflow_call.inputs.$input.type" "$file".bak)
      required=$(yq ".on.workflow_call.inputs.$input.required" "$file".bak)
      description=$(yq ".on.workflow_call.inputs.$input.description" "$file".bak)

      cat >> "$file" <<-EOF
      # TODO insert correct value for $input
      # type: $type
      # required: $required
      # description: $description
      $input: "my-special-value"
EOF
    done

    rm "$file.bak"
  fi

  # remove the comment char for all lines between USE_REPOSITORY and /USE_REPOSITORY in the file
  sed -i '/USE_REPOSITORY/,/\/USE_REPOSITORY/s/^#//' "$file"

  # remove the everything between USE_WORKFLOW and /USE_WORKFLOW
  sed -i '/USE_WORKFLOW/,/\/USE_WORKFLOW/d' "$file"

  # remove the marker lines
  sed -i '/USE_REPOSITORY/d' "$file"
  sed -i '/\/USE_REPOSITORY/d' "$file"
  sed -i '/USE_WORKFLOW/d' "$file"
  sed -i '/\/USE_WORKFLOW/d' "$file"
done

#
# Remove the prefix from the workflow files
#
prefixes=("default_" "terraform_module_" "docker_" "maven_")

# iterate over each file in the directory
for file in "$destination_path"/.github/workflows/*.yml
do
  # get the base name of the file
  base_name=$(basename "$file")

  # iterate over each prefix
  for prefix in "${prefixes[@]}"
  do
    # check if the file name starts with the prefix
    if [[ $base_name == $prefix* ]]; then
      # remove the prefix
      new_name=${base_name#"$prefix"}

      # rename the file
      mv "$file" "$destination_path/.github/workflows/$new_name"

      # break the loop as the prefix has been found and removed
      break
    fi
  done
done

#
# Remove the suffix from the workflow files
#
suffixes=("_callable.yml")

# iterate over each file in the directory
for file in "$destination_path"/.github/workflows/*.yml
do
  # get the base name of the file
  base_name=$(basename "$file")

  # iterate over each suffix
  for suffix in "${suffixes[@]}"
  do
    # check if the file name starts with the prefix
    if [[ $base_name == *$suffix ]]; then
      # remove the suffix
      new_name="${base_name%"$suffix"}.yml"

      # rename the file
      mv "$file" "$destination_path/.github/workflows/$new_name"

      # break the loop as the suffix has been found and removed
      break
    fi
  done
done

create_commit_and_pr "$destination_path"
