#!/usr/bin/env bash

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Output functions
log_info() {
  echo -e "${BLUE}ℹ ${NC}$*"
}

log_success() {
  echo -e "${GREEN}✓ ${NC}$*"
}

log_warn() {
  echo -e "${YELLOW}⚠ ${NC}$*"
}

log_error() {
  echo -e "${RED}✗ ${NC}$*"
}

log_section() {
  echo ""
  echo -e "${MAGENTA}════════════════════════════════════════${NC}"
  echo -e "${MAGENTA}${NC} $*"
  echo -e "${MAGENTA}════════════════════════════════════════${NC}"
}

init_mode="false"
repository_type=""
repository_path=$(pwd)
skip_pr="false"
force_execution="false"

CONFIG_FILE=".config/workflow.yml"

branch_name="update-workflows-$(date +%s)"

function ensure_prerequisites_or_exit() {
  log_section "Checking Prerequisites"

  if ! command -v pre-commit &> /dev/null; then
    log_error "pre-commit is not installed. https://github.com/pre-commit/pre-commit"
    exit 1
  fi
  log_success "pre-commit found"

  if ! command -v yq &> /dev/null; then
    log_error "yq is not installed. https://github.com/mikefarah/yq"
    exit 1
  fi
  log_success "yq found"

  if ! command -v gh &> /dev/null; then
    log_error "gh is not installed. Please install it from https://cli.github.com/"
    exit 1
  fi
  log_success "gh found"
}

function ensure_repo_preconditions_or_exit() {
  if [ "$init_mode" == "true" ] || [ "$force_execution" == "true" ]; then
    return
  fi

  # ensure a clean working directory
  if [ -n "$(git status --porcelain)" ]; then
    log_error "The working directory is not clean. Please use a clean copy so no unintended changes are merged."
    exit 1
  fi
  log_success "Working directory is clean"
}

function show_help_and_exit() {
  echo "Usage: $0 --dry-run --init --force <repository-path>"

  echo "repository-path: the path to the repository to update"
  echo "--dry-run: (optional) do not create a PR"
  echo "--init: (optional) create an initial configuration file if not present"
  echo "--force: (optional) force execution even if the working directory is not clean"

  exit 1
}

function create_commit_and_pr() {
  log_section "Creating Commit and Pull Request"
  workflow_tag=$1

  log_info "Staging all changes..."
  git add .
  # use --no-verify to skip pre-commit hooks as they might fail. Checks are done in the workflows anyway.
  log_info "Creating commit with message: 'update workflows to $workflow_tag'"
  git commit -m "update workflows to $workflow_tag" --no-verify
  log_success "Commit created"

  log_info "Pushing changes to origin..."
  git push origin HEAD
  log_success "Changes pushed to origin"

  body=$(cat <<EOF
# Description

This PR updates all workflows to version $workflow_tag.

# Verification

Done by the workflows in this feature branch, except for the release workflow.
EOF
  )

  if [ "$skip_pr" == "true" ]; then
    log_warn "No PR created, but the changes were committed and pushed."
  else
    log_info "Creating pull request..."
    gh pr create --title "ci(deps): update workflows to $workflow_tag" --body "$body" --base main
    log_success "Pull request created"
    log_info "Opening PR in web browser..."
    gh pr view --web
  fi
}

function ensure_and_set_parameters_or_exit() {
  POSITIONAL_ARGS=()

  while [[ $# -gt 0 ]]; do
    case $1 in
      --skip-pr)
        skip_pr="true"
        log_info "Skip PR mode enabled"
        shift
        ;;
      --init)
        init_mode="true"
        log_info "Init mode enabled"
        shift
        ;;
      --*|-*)
        log_error "Unknown option $1"
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

  repository_path=$1
  log_info "Repository path set to: $repository_path"
}

function setup_cspell() {
  log_info "Setting up cspell dictionaries..."
  latest_template_path=$1

  # init the dictionaries
  if [ ! -d .config/dictionaries ]; then
    log_info "Creating dictionaries directory from template..."
    cp -pr "$latest_template_path/.config/dictionaries" .config/

    # project dictionary, create an empty one instead of copying the template
    rm .config/dictionaries/project.txt
    touch .config/dictionaries/project.txt
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
  log_success "cspell dictionaries setup complete"
}

function ensure_config_file_or_create_dummy_in_new_branch_and_exit() {
  if [ ! -f "$CONFIG_FILE" ]; then
    log_warn "Configuration file not found: $CONFIG_FILE"
    log_info "Fetching main branch..."
    git fetch origin main
    log_info "Creating new branch: $branch_name"
    git checkout -b "$branch_name" origin/main

    log_info "Creating dummy configuration file..."
    mkdir -p .config
    cat > "$CONFIG_FILE" <<-EOF
---
# configuration for workflow automation from https://github.com/HapagLloyd/workflow-templates
repository:
  type: github-only # docker, github-only, maven, python, terraform_module
  release: auto # auto, manual
EOF

    log_error "Please review and adjust the configuration as needed, then re-run the script with the '--init' option."
    exit 2
  fi
  log_success "Configuration file found: $CONFIG_FILE"
}

function fetch_and_validate_configuration_from_file_or_exit() {
  log_section "Validating Configuration"
  repository_type=$(yq e '.repository.type' "$CONFIG_FILE")
  release_type=$(yq e '.repository.release' "$CONFIG_FILE")

  log_info "Repository type: $repository_type"
  log_info "Release type: $release_type"

  if [ "$repository_type" != "github-only" ] && [ "$repository_type" != "maven" ] && [ "$repository_type" != "terraform_module" ] && [ "$repository_type" != "docker" ] && [ "$repository_type" != "python" ]; then
    log_error "The repository type $repository_type is not supported."
    log_error "Supported types are: docker, github-only, maven, python, terraform_module"
    exit 3
  fi

  if [ "$repository_type" != "terraform_module" ] && [ "$release_type" == "manual" ]; then
    log_error "The release type 'manual' is supported for terraform_module repositories only."
    exit 3
  fi
  log_success "Configuration is valid"
}

function setup_renovate() {
  log_info "Setting up Renovate configuration"
  cat > .github/renovate.json5 <<-EOF
{
  \$schema: "https://docs.renovatebot.com/renovate-schema.json",
  extends: ["github>Hapag-Lloyd/Renovate-Global-Configuration"],
}
EOF
  log_success "Renovate configuration created"
}

ensure_and_set_parameters_or_exit "$@"
ensure_prerequisites_or_exit
ensure_config_file_or_create_dummy_in_new_branch_and_exit
ensure_repo_preconditions_or_exit

latest_template_path=$(dirname "$0")

log_section "Starting Workflow Update"
log_info "Updating the workflows in $repository_path"
cd "$repository_path" || exit 8

fetch_and_validate_configuration_from_file_or_exit

# in init mode, we create a new branch from main already as we created the initial config file
if [ "$init_mode" == "false" ]; then
  log_info "Fetching origin main..."
  git fetch origin main
  log_info "Creating new branch: $branch_name"
  git checkout -b "$branch_name" origin/main
fi

log_section "Copying Workflow Files"

# enable nullglob to prevent errors when no files are found
shopt -s nullglob

# basic setup for all types
log_info "Creating workflow directories..."
mkdir -p ".github/workflows/scripts"

log_info "Copying default workflow templates..."
cp "$latest_template_path/.github/workflows/default"_* .github/workflows/
cp "$latest_template_path/.github/workflows/scripts/"* .github/workflows/scripts/

log_info "Copying GitHub configuration files..."
cp "$latest_template_path/.github/pull_request_template.md" .github/
cp "$latest_template_path/.github/CODE_OF_CONDUCT.md" .github/
cp "$latest_template_path/.github/CONTRIBUTING.md" .github/
cp "$latest_template_path/.github/renovate.json5" .github/
cp "$latest_template_path/update_workflows_user.sh" .github/update_workflows.sh

log_info "Setting executable permissions on scripts..."
git ls-files --modified -z .github/workflows/scripts/ .github/update_workflows.sh | xargs -0 -I {} git update-index --chmod=+x {}
git ls-files -z -o --exclude-standard | xargs -0 -I {} git update-index --add --chmod=+x {}

log_info "Copying configuration files..."
mkdir -p .config
# copy fails if a directory is hit. dictionaries/ is handled in the setup_cspell function
cp -p "$latest_template_path/.config/"*.* .config/
cp -p "$latest_template_path/.config/".*.* .config/

setup_cspell "$latest_template_path"

# we do not have special files for simple GitHub projects, this is handled by the default setup
if [ "$repository_type" != "github-only" ]; then
  log_info "Copying repository-type specific workflows ($repository_type)..."
  cp "$latest_template_path/.github/workflows/${repository_type}"_* .github/workflows/
fi

# setup the release workflow
if [ "$release_type" == "manual" ]; then
  log_info "Removing auto-release workflow for manual release mode..."
  rm .github/workflows/default*release*_callable.yml
fi

log_section "Processing Workflow Files"
# Fix the "on" clause in the workflow files, remove all jobs and set a reference to this repository
#
log_info "Retrieving template version information..."
version_info=$(
  cd "$latest_template_path" || exit 9

  # add a reference to this repository which holds the workflow
  commit_sha=$(git rev-parse HEAD)
  tag=$(git describe --tags "$(git rev-list --tags --max-count=1)" || true)

  echo "$commit_sha" "$tag"
)

commit_sha=$(echo "$version_info" | cut -d " " -f 1)
tag=$(echo "$version_info" | cut -d " " -f 2)

log_success "Template version: $tag (commit: ${commit_sha:0:7})"

# iterate over each file in the directory
log_info "Processing workflow files..."
for file in .github/workflows/*.yml
do
  base_name=$(basename "$file")
  log_info "  Processing: $base_name"

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
      default="\"my special value\""
      todo="# TODO insert correct value for $input"$'\n'"      "

      case "$input" in
        "python-version")
          # no expansion of the variable as it is a string we want to keep
          # shellcheck disable=SC2016
          default='${{ vars.PYTHON_VERSION }}'
          todo=""
          ;;
        "python-versions")
          # no expansion of the variable as it is a string we want to keep
          # shellcheck disable=SC2016
          default='${{ vars.PYTHON_VERSIONS }}'
          todo=""
          ;;
        "pypi-url")
          # no expansion of the variable as it is a string we want to keep
          # shellcheck disable=SC2016
          default='${{ vars.PYPI_URL }}'
          todo=""
          ;;
        *)
          ;;
      esac

      cat >> "$file" <<-EOF
      $todo# type: $type
      # required: $required
      # description: $description
      $input: $default
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

log_success "All workflow files processed"

log_section "Finalizing File Names"

#
# Remove the prefix from the workflow files
#
prefixes=("default_" "terraform_module_" "docker_" "maven_" "python_")

# iterate over each file in the directory
log_info "Removing workflow prefixes..."
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
      log_info "  Renamed: $base_name → $new_name"
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
log_info "Removing workflow suffixes..."
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
      log_info "  Renamed: $base_name → $new_name"
      mv "$file" ".github/workflows/$new_name"

      # break the loop as the suffix has been found and removed
      break
    fi
  done
done

log_section "Finalizing Setup"

setup_renovate

log_info "Installing pre-commit hooks..."
pre-commit install -c .config/.pre-commit-config.yaml
log_success "Pre-commit hooks installed"

create_commit_and_pr "$tag"
