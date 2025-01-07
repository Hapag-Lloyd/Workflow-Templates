#!/bin/bash

#
# Based on the idea outlined in https://github.com/streetsidesoftware/cspell/issues/2536#issuecomment-1126077282
# but with a few modifications to fit the needs of our project.
#

set -euo pipefail

MISSPELLED_WORDS_PATH="misspelled-words.txt"

CSPELL_CONFIGURATION_FILE=$(find . -name "cspell.json" | head -n 1)
DICTIONARIES_PATH=".config/dictionaries"
mapfile -t DICTIONARY_FILES_TO_CHECK < <(ls .config/dictionaries/*.txt)

# Make a list of every misspelled word without any custom dictionaries and configuration file
mv "$CSPELL_CONFIGURATION_FILE" "${CSPELL_CONFIGURATION_FILE}.temp"
npx cspell . --dot --no-progress --no-summary --unique --words-only --no-exit-code --exclude ".git/**" --exclude "$DICTIONARIES_PATH/**" | sort --ignore-case --unique > "$MISSPELLED_WORDS_PATH"

# Check the custom dictionaries
ONE_OR_MORE_FAILURES=0
for DICTIONARY_NAME in "${DICTIONARY_FILES_TO_CHECK[@]}"; do
  echo "Checking for orphaned words in dictionary: $DICTIONARY_NAME"

  # ensure the dictionary is sorted and unique
  sort --ignore-case --unique --check "$DICTIONARY_NAME" > /dev/null

  # Check that each word in the dictionary is actually being used
  while IFS= read -r line; do
    # Remove any trailing newline characters
    line=$(echo "$line" | tr -d '\r\n')

    if ! grep "$line" "$MISSPELLED_WORDS_PATH" --ignore-case --silent ; then
      echo "The following word in the $DICTIONARY_NAME dictionary is not being used: ($line)"
      ONE_OR_MORE_FAILURES=1
    fi
  done < "$DICTIONARY_NAME"
done

rm -f "$MISSPELLED_WORDS_PATH"

if [ $ONE_OR_MORE_FAILURES -ne "0" ]; then
  echo "Dictionary check failed."
  exit 1
fi

echo "All dictionaries are valid."
