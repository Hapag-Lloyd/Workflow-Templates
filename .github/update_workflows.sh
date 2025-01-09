#!/usr/bin/env bash
set -euo pipefail

cli_parameters="$*"
repository_type=""
release_type="auto"
force_execution="false"
repository_path=$(pwd)

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

function ensure_running_on_the_newest_copy_or_restart() {
  if [ "$force_execution" == "true" ]; then
    return
  fi

  # get list of changed files
  changed_files=$(git diff --name-only)

  # check if the script is part of the changed files
  if ! echo "$changed_files" | grep -q "update_workflows.sh"; then
    echo "Restarting the script with the latest version ..."

    # copy script to temp file and execute it
    temp_script=$(mktemp -t update_workflows-XXXXX)
    cp ".github/update_workflows.sh" "$temp_script"

    # shellcheck disable=SC2086 # original script parameters are passed to the new script
    bash "$temp_script" $cli_parameters --force "$repository_path"
    exit 0
  fi
}

function ensure_repo_preconditions_or_exit() {
  # TODO
  return

  if [ "$force_execution" == "true" ]; then
    return
  fi

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

  # ensure top level directory of the repository
  if [ ! -d .github ]; then
    echo "The script must be executed from the top level directory of the repository."
    exit 1
  fi
}

function show_help_and_exit() {
  echo "Usage: $0 <repository-type> --release-type auto|manual"
  echo "repository-type: docker, github-only, maven, terraform_module"
  echo "release-type: (optional)"
  echo "  auto: the release will be triggered automatically on a push to the default branch"
  echo "  manual: the release will be triggered manually via separate PR, which is created automatically"

  exit 1
}

function create_commit_and_pr() {
  local repo_directory=$1

  cd "$repo_directory" || exit 7

  branch_name="update-workflows-$(date +%s)"
  git checkout -b "$branch_name"

  git add .
  git commit -m "update workflows to latest version"
  git push --set-upstream origin "$branch_name"

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
      -f|--force)
        force_execution="true"
        repository_path=$2
        shift
        shift
        ;;
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

    if [ "${#POSITIONAL_ARGS[@]}" -ne 1 ]; then
    show_help_and_exit
  fi

  repository_type=$1

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
  latest_template_path=$1

  # init the dictionaries
  if [ ! -d .config/dictionaries ]; then
    cp -pr "$latest_template_path/.config/dictionaries" .config/
  fi
  # unknown words for copied workflows
  cp -p "$latest_template_path/.config/dictionaries/workflow.txt" .config/dictionaries/

  # the dictionaries for the specific repository types, managed by other repositories
  if [ ! -f .config/dictionaries/maven.txt ]; then
      touch .config/dictionaries/maven.txt
  fi
  if [ ! -f .config/dictionaries/terraform-module.txt ]; then
      touch .config/dictionaries/terraform-module.txt
  fi
  if [ ! -f .config/dictionaries/docker.txt ]; then
      touch .config/dictionaries/docker.txt
  fi
  if [ ! -f .config/dictionaries/simple.txt ]; then
      touch .config/dictionaries/simple.txt
  fi
  if [ ! -f .config/dictionaries/python.txt ]; then
      touch .config/dictionaries/python.txt
  fi

  # project dictionary for the rest, do not overwrite
  if [ ! -f .config/dictionaries/project.txt ]; then
    touch .config/dictionaries/project.txt
  fi

  # fix the "addWords" setting needed for some IDEs
  jq 'del(.dictionaryDefinitions[] | select(.addWords) | .addWords)' .config/cspell.json > .config/cspell.json.tmp

  repository_name=$(basename "$(pwd)")

  if [ "$repository_name" == "Repository-Template-Docker" ]; then
    jq '(.dictionaryDefinitions[] | select(.name == "docker")).addWords |= true' .config/cspell.json.tmp > .config/cspell.json
  elif [ "$repository_name" == "Repository-Template-Maven" ]; then
    jq '(.dictionaryDefinitions[] | select(.name == "maven")).addWords |= true' .config/cspell.json.tmp > .config/cspell.json
  elif [ "$repository_name" == "Repository-Template-Terraform-Module" ]; then
    jq '(.dictionaryDefinitions[] | select(.name == "terraform-module")).addWords |= true' .config/cspell.json.tmp > .config/cspell.json
  elif [ "$repository_name" == "Repository-Template-Simple" ]; then
    jq '(.dictionaryDefinitions[] | select(.name == "simple")).addWords |= true' .config/cspell.json.tmp > .config/cspell.json
  elif [ "$repository_name" == "Repository-Template-Python" ]; then
    jq '(.dictionaryDefinitions[] | select(.name == "python")).addWords |= true' .config/cspell.json.tmp > .config/cspell.json
  else
    jq '(.dictionaryDefinitions[] | select(.name == "project")).addWords |= true' .config/cspell.json.tmp > .config/cspell.json
  fi

  rm .config/cspell.json.tmp
}

ensure_and_set_parameters_or_exit "$@"
ensure_prerequisites_or_exit
ensure_repo_preconditions_or_exit

cd "$repository_path" || exit 8
echo "Updating the workflows in $repository_path"

echo "Fetching the latest version of the workflows"

latest_template_path=xvü # $(mktemp -p . -d -t repository-template-XXXXX)
if [ -d "$latest_template_path" ]; then
  rm -rf "$latest_template_path"
fi

echo "i $(pwd)"
gh repo clone https://github.com/Hapag-Lloyd/Workflow-Templates.git "$latest_template_path"

# TODO
(cd "$latest_template_path" && git checkout kayma/update-workflows)

echo "i $(pwd)"
ls -lad $(pwd)/*
# enable nullglob to prevent errors when no files are found
shopt -s nullglob

# basic setup for all types
mkdir -p ".github/workflows/scripts"
cp "$latest_template_path/.github/workflows/default"_* .github/workflows/

cp "$latest_template_path/.github/workflows/scripts/"* .github/workflows/scripts/
# TODO
# git update-index --chmod=+x .github/workflows/scripts/*.sh

cp "$latest_template_path/.github/.pre-commit-config.yaml" .github/
cp "$latest_template_path/.github/pull_request_template.md" .github/
cp "$latest_template_path/.github/renovate.json5" .github/

cp "$latest_template_path/.github/update_workflows.sh" .github/
# TODO
# git update-index --chmod=+x .github/update_workflows.sh
ensure_running_on_the_newest_copy_or_restart

mkdir -p .config
# copy fails if a directory is hit. dictionaries/ is handled in the setup_cspell function
cp -p "$latest_template_path/.config/"*.* .config/

setup_cspell "$latest_template_path"

# we do not have special files for simple GitHub projects, this is handled by the default setup
if [ "$repository_type" != "github-only" ]; then
  cp "$latest_template_path/.github/workflows/${repository_type}"_* .github/workflows/
fi

# setup the release workflow
if [ "$release_type" == "manual" ]; then
  rm .github/workflows/default*release*_callable.yml
fi

rm -rf "$latest_template_path"

#
# Fix the "on" clause in the workflow files, remove all jobs and set a reference to this repository
#

x=$(
  cd "$latest_template_path" || exit 9

  # add a reference to this repository which holds the workflow
  commit_sha=$(git rev-parse HEAD)
  tag=$(git describe --tags "$(git rev-list --tags --max-count=1)" || true)

  echo "$commit_sha" "$tag"
)

commit_sha=$(echo $x | awk '{print $1}')
tag=$(echo $x | awk '{print $2}')

# iterate over each file in the directory
for file in .github/workflows/*.yml
do
  base_name=$(basename "$file")

  # remove everything else as we will reference the file in this repository
  sed -i '/jobs:/,$d' "$file"

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
  sed -i '/USE_REPOSITORY/,/\/USE_REPOSITORY/s/^# //' "$file"

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
for file in .github/workflows/*.yml
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
      mv "$file" ".github/workflows/$new_name"

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
for file in .github/workflows/*.yml
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
      mv "$file" ".github/workflows/$new_name"

      # break the loop as the suffix has been found and removed
      break
    fi
  done
done

create_commit_and_pr .
