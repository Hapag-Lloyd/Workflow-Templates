#!/usr/bin/env bash
set -euo pipefail

destination_path=""
repository_type=""

function check_prerequisites() {
  if ! command -v yq &> /dev/null; then
    echo "yq is not installed. https://github.com/mikefarah/yq"
    exit 1
  fi
}

function check_and_set_parameters() {
  POSITIONAL_ARGS=()

  while [[ $# -gt 0 ]]; do
    case $1 in
      --*|-*)
        echo "Unknown option $1"
        exit 1
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
    echo "Usage: $0 <path-to-new-repo> <repository-type>"
    exit 1
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
    exit 3
  fi
}

check_prerequisites
check_and_set_parameters "$@"

# enable nullglob to prevent errors when no files are found
shopt -s nullglob

# basic setup for all types
mkdir -p "$destination_path/.github/workflows"
cp .github/workflows/default_* .github/workflows/release_* "$destination_path/.github/workflows/"

# we do not have special files for simple GitHub projects, this is handled by the default setup
if [ "$repository_type" != "github-only" ]; then
  cp ".github/workflows/${repository_type}"_* "$destination_path/.github/workflows/"
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

  cat >> "$file" <<-EOF
jobs:
  default:
    uses: Hapag-Lloyd/Workflow-Templates/.github/workflows/$base_name@$commit_sha
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
