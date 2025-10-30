#!/bin/bash

# Rebase is nice, but not when you have to do it twice when transferring commits between branches
if [ $# -eq 1 ]; then
    git merge $1 --no-ff --no-edit
    exit 0
else
    echo "Enter the branch name to merge"
    exit 1
fi
