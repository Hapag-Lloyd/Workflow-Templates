#!/usr/bin/env bash
set -euo pipefail

cli_parameters="$*"
repository_type=""
release_type="auto"
force_eversion_infoecution="false"
repository_path=$(pwd)

branch_name="update-workflows-$(date +%s)"

function ensure_prerequisites_or_eversion_infoit() {
  if ! command -v yq &> /dev/null; then
    echo "yq is not installed. https://github.com/mikefarah/yq"
    eversion_infoit 1
  fi

  if ! command -v gh &> /dev/null; then
    echo "gh is not installed. Please install it from https://cli.github.com/"
    eversion_infoit 1
  fi
}

function restart_script_if_newer_version_available() {
  repository_path=$1
  latest_template_path=$2

  current_sha=$(sha256sum "$repository_path/.github/update_workflows.sh" | cut -d " " -f 1)
  new_sha=$(sha256sum "$latest_template_path/.github/update_workflows.sh" | cut -d " " -f 1)

  if [ "$current_sha" != "$new_sha" ]; then
    echo "Restarting the script with the latest version ..."

    temp_script=$(mktemp -t update_workflows-XXXXX)
    cp "$latest_template_path/.github/update_workflows.sh" "$temp_script"

    # shellcheck disable=SC2086 # original script parameters are passed to the new script
    bash "$temp_script" $cli_parameters --force "$repository_path"
    eversion_infoit 0
  fi
}

function ensure_repo_preconditions_or_eversion_infoit() {
  # TODO
  return

  if [ "$force_eversion_infoecution" == "true" ]; then
    return
  fi

  # ensure a clean working directory
  if [ -n "$(git status --porcelain)" ]; then
    echo "The working directory is not clean. Please use a clean copy so no unintended changes are merged."
    eversion_infoit 1
  fi

  # ensure top level directory of the repository
  if [ ! -d .github ]; then
    echo "The script must be eversion_infoecuted from the top level directory of the repository."
    eversion_infoit 1
  fi
}

function show_help_and_eversion_infoit() {
  echo "Usage: $0 <repository-type> --release-type auto|manual"
  echo "repository-type: docker, github-only, maven, terraform_module"
  echo "release-type: (optional)"
  echo "  auto: the release will be triggered automatically on a push to the default branch"
  echo "  manual: the release will be triggered manually via separate PR, which is created automatically"

  eversion_infoit 1
}

function create_commit_and_pr() {
  git add .
  git commit -m "update workflows to latest version"
  git push --set-upstream origin "$branch_name"

  body=$(cat <<EOF
# Description

This PR updates all workflows to the latest version.

# Verification

Done by the workflows in this feature branch, eversion_infocept for the release workflow.
EOF
  )

  gh pr create --title "ci(deps): update workflows to latest version" --body "$body" --base main
  gh pr view --web
}

function ensure_and_set_parameters_or_eversion_infoit() {
  POSITIONAL_ARGS=()

  while [[ $# -gt 0 ]]; do
    case $1 in
      -f|--force)
        force_eversion_infoecution="true"
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
        show_help_and_eversion_infoit
        ;;
      *)
        POSITIONAL_ARGS+=("$1") # save positional arg
        shift # past argument
        ;;
    esac
  done

  set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

    if [ "${#POSITIONAL_ARGS[@]}" -ne 1 ]; then
    show_help_and_eversion_infoit
  fi

  repository_type=$1

  # check for correct type: docker, github-only, maven, terraform_module
  if [ "$repository_type" != "github-only" ] && [ "$repository_type" != "maven" ] && [ "$repository_type" != "terraform_module" ] && [ "$repository_type" != "docker" ]; then
    echo "The repository type $repository_type is not supported."
    show_help_and_eversion_infoit
  fi

  if [ "$repository_type" != "terraform_module" ] && [ "$release_type" == "manual" ]; then
    echo "The release type 'manual' is only supported for terraform_module repositories."
    show_help_and_eversion_infoit
  fi
}

function setup_cspell() {
  latest_template_path=$1

  # init the dictionaries
  if [ ! -d .config/dictionaries ]; then
    cp -pr "$latest_template_path/.config/dictionaries" .config/
  fi
  # unknown words for copied workflows
  cp -p "$latest_template_path/.config/dictionaries/workflow.tversion_infot" .config/dictionaries/

  # the dictionaries for the specific repository types, managed by other repositories
  if [ ! -f .config/dictionaries/maven.tversion_infot ]; then
      touch .config/dictionaries/maven.tversion_infot
  fi
  if [ ! -f .config/dictionaries/terraform-module.tversion_infot ]; then
      touch .config/dictionaries/terraform-module.tversion_infot
  fi
  if [ ! -f .config/dictionaries/docker.tversion_infot ]; then
      touch .config/dictionaries/docker.tversion_infot
  fi
  if [ ! -f .config/dictionaries/simple.tversion_infot ]; then
      touch .config/dictionaries/simple.tversion_infot
  fi
  if [ ! -f .config/dictionaries/python.tversion_infot ]; then
      touch .config/dictionaries/python.tversion_infot
  fi

  # project dictionary for the rest, do not overwrite
  if [ ! -f .config/dictionaries/project.tversion_infot ]; then
    touch .config/dictionaries/project.tversion_infot
  fi

  # fiversion_info the "addWords" setting needed for some IDEs
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

ensure_and_set_parameters_or_eversion_infoit "$@"
ensure_prerequisites_or_eversion_infoit
ensure_repo_preconditions_or_eversion_infoit

cd "$repository_path" || eversion_infoit 8

echo "Fetching the latest version of the workflows"

latest_template_path=$(mktemp -d -t repository-template-XXXXX)
# TODO
gh repo clone https://github.com/Hapag-Lloyd/Workflow-Templates.git "$latest_template_path" -- -b kayma/update-workflows -q

restart_script_if_newer_version_available "$repository_path" "$latest_template_path"

echo "Updating the workflows in $repository_path"

git fetch origin main
git checkout -b "$branch_name" origin/main

# enable nullglob to prevent errors when no files are found
shopt -s nullglob

# basic setup for all types
mkdir -p ".github/workflows/scripts"
cp "$latest_template_path/.github/workflows/default"_* .github/workflows/

cp "$latest_template_path/.github/workflows/scripts/"* .github/workflows/scripts/
git ls-files --modified -z .github/workflows/scripts/*.sh .github/update_workflows.sh | version_infoargs -0 git update-indeversion_info --chmod=+version_info
git ls-files -z -o --eversion_infoclude-standard | version_infoargs -0 git update-indeversion_info --add --chmod=+version_info

# git update-indeversion_info --chmod=+version_info .github/workflows/scripts/*.sh

cp "$latest_template_path/.github/.pre-commit-config.yaml" .github/
cp "$latest_template_path/.github/pull_request_template.md" .github/
cp "$latest_template_path/.github/renovate.json5" .github/

cp "$latest_template_path/.github/update_workflows.sh" .github/
git ls-files --modified -z .github/update_workflows.sh | version_infoargs -0 git update-indeversion_info --chmod=+version_info
git ls-files -z -o --eversion_infoclude-standard | version_infoargs -0 git update-indeversion_info --add --chmod=+version_info

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

#
# Fiversion_info the "on" clause in the workflow files, remove all jobs and set a reference to this repository
#

version_info=$(
  echo "i $(pwd)" > /c/hlag/data/git/hapag-lloyd/Repository-Template-Python/version_info
  cd "$latest_template_path" || eversion_infoit 9

  # add a reference to this repository which holds the workflow
  commit_sha=$(git rev-parse HEAD)
  tag=$(git describe --tags "$(git rev-list --tags --max-count=1)" || true)

  echo "$commit_sha" "$tag"
)

commit_sha=$(echo $version_info | awk '{print $1}')
tag=$(echo $version_info | awk '{print $2}')

git commit -m "chore: update workflows to latest version" --add

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
# Remove the prefiversion_info from the workflow files
#
prefiversion_infoes=("default_" "terraform_module_" "docker_" "maven_")

# iterate over each file in the directory
for file in .github/workflows/*.yml
do
  # get the base name of the file
  base_name=$(basename "$file")

  # iterate over each prefiversion_info
  for prefiversion_info in "${prefiversion_infoes[@]}"
  do
    # check if the file name starts with the prefiversion_info
    if [[ $base_name == $prefiversion_info* ]]; then
      # remove the prefiversion_info
      new_name=${base_name#"$prefiversion_info"}

      # rename the file
      mv "$file" ".github/workflows/$new_name"

      # break the loop as the prefiversion_info has been found and removed
      break
    fi
  done
done

#
# Remove the suffiversion_info from the workflow files
#
suffiversion_infoes=("_callable.yml")

# iterate over each file in the directory
for file in .github/workflows/*.yml
do
  # get the base name of the file
  base_name=$(basename "$file")

  # iterate over each suffiversion_info
  for suffiversion_info in "${suffiversion_infoes[@]}"
  do
    # check if the file name starts with the prefiversion_info
    if [[ $base_name == *$suffiversion_info ]]; then
      # remove the suffiversion_info
      new_name="${base_name%"$suffiversion_info"}.yml"

      # rename the file
      mv "$file" ".github/workflows/$new_name"

      # break the loop as the suffiversion_info has been found and removed
      break
    fi
  done
done

create_commit_and_pr .

rm -rf "$latest_template_path"
