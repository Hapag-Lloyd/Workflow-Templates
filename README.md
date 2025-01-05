# Workflow-Templates

This repository stores templates used to set up workflows for new repositories.

## Set up a new repository

Clone this repository to your disk and run `setup-workflows.sh`. It copies the necessary files to the correct
locations in your new repository.

```bash
./update-workflows.sh <path-to-new-repository> <type>
```

Search for `TODO` in the copied files and replace the placeholders with the correct values. The same script can be used to update
all files in case of major changes in the templates.

:warning: Make sure to run the script from the latest `main` branch to get the most recent templates.

## What you get

### Default setup

- Release management is done with [semantic-release](https://github.com/semantic-release/semantic-release). Releases are automatically
  tagged and published on GitHub. Special releases for Maven Central and Terraform modules are supported.
- stale issue and PR management
- welcome message for contributors
- linters for all files
- PRs are checked for semantic commit titles to ensure an automatic release
- ChatOps to run workflows from comments

## For Developers - Repository Layout

1. Add all workflows to `.github/workflows/`, otherwise they can't be referenced from the repositories.
2. Workflows with `this_` prefix are used for this repository only.
3. Workflows with `default_` prefix are added to every new repository. Otherwise use the correct prefix for the project type.

The script to set up the workflows for new repositories is `setup-workflows.sh`. It copies the necessary files to the new
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
