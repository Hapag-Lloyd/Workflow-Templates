# Workflow-Templates

This repository stores templates used to set up workflows for new repositories.

## Set up a new repository

1. Copy the [update_workflows_user.sh](./update_workflows_user.sh) script to your new repository.
2. Execute the script in your repository.
3. Store the correct workflow settings in `.config/workflow.yml`:
4. Rerun the script with `--init` option.
5. Search for `TODO` in the copied files and replace the placeholders with the correct values.
6. Check the PR which was automatically created by the script and merge it.

## Update existing repositories

1. Execute `.github/update_workflows.sh` in the repository you want to update.
2. Check the PR which was automatically created by the script and merge it.

Invoke the script with --skip-pr to see the changes but without creating a PR.

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
- Renovate setup with Hapag-Lloyd specific presets

## For Developers - Repository Layout

1. Add all workflows to `.github/workflows/`, otherwise they can't be referenced from the repositories.
2. Workflows with `this_` prefix are used for this repository only.
3. Workflows with `default_` prefix are added to every new repository. Otherwise, use the correct prefix for the project type.

The script to set up the workflows for new repositories is `./update_workflows.sh`. It copies the necessary files to the new
repository. It starts with the default workflows and adds the specific ones based on the project type. In case of a filename clash,
the specific template overwrites the default one (exception: `.gitignore` These files are concatenated).

The script `./update_workflows_user.sh` is copied to `.github/update_workflows.sh` and executed in the repository by the user. It
simply clones this repository and calls the main script with the correct parameters.

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
