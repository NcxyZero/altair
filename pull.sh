#!/bin/bash

# When you want to pull with uncommitted changes
git pull --rebase --autostash

# If you just want to match the repo state, use:
# git reset --hard HEAD^
# git rebase --abort
# git stash drop
