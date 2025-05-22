# Workflow-Templates

This repository stores templates used to set up workflows for new repositories.

## Set up a new repository

```bash
git clone https://github.com/Hapag-Lloyd/Workflow-Templates.git workflow-templates
./update_workflows.sh <type> <path-to-new-repository>
```

Search for `TODO` in the copied files and replace the placeholders with the correct values. The same script can be used to update
all files in case of major changes in the templates.

## Update existing repositories

```bash
  cd <path-to-this-repository>
  git checkout main
  git pull

  ./update_workflows.sh <repository-type> <repository-path> --release-type auto|manual --dry-run --use-existing-branch
```

Use without `--dry-run` to apply the changes and create a pull request. `--use-existing-branch` is useful to update a Renovate MR.
Make sure to checkout the branch first.

## What you get

### Default setup

- Release management is done with [semantic-release](https://github.com/semantic-release/semantic-release). Releases are automatically
  tagged and published on GitHub. Special releases for Maven Central and Terraform modules are supported.
- stale issue and PR management
- welcome message for contributors
- linters for all files
- PRs are checked for semantic commit titles to ensure an automatic release
- ChatOps to run workflows from comments
- a `.config/dictionaries/project.txt` file for the spell checker exceptions

## For Developers - Repository Layout

1. Add all workflows to `.github/workflows/`, otherwise they can't be referenced from the repositories.
2. Workflows with `this_` prefix are used for this repository only.
3. Workflows with `default_` prefix are added to every new repository. Otherwise, use the correct prefix for the project type.

The script to set up the workflows for new repositories is `./update_workflows.sh`. It copies the necessary files to the new
repository. It starts with the default workflows and adds the specific ones based on the project type. In case of a filename clash,
the specific template overwrites the default one (exception: `.gitignore` These files are concatenated).

Use

```bash
# USE_REPOSITORY
#  push:
#    branches:
#      - main
# /USE_REPOSITORY
```

in the file to describe the triggers which should be used in the repository. The script will automatically replace the triggers
marked with `USE_WORKFLOW` which are valid within this repository only.

Make sure that this block is well formatted, otherwise the update script will fail in the related repository due to prettier.

### Simulate the update

Use the `simulate.sh` script to check the changes before applying them to the repository. The script

- creates a new repository called `simulate-*` and applies the changes there
- updates the `workflow.txt` dictionary in your current branch

### Spell Checker

1. Add the words to the `.config/dictionaries/workflow.txt` file.
2. `.config/dictionaries/project.txt` file is used for the project specific words of the project being set up.
3. All other dictionaries are managed by the `Repository-Template-*` repositories.
