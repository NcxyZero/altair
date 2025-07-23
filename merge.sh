#!/bin/bash
# Rebase jest fajny, ale nie jak musisz robić go 2 razy przy transferze commitów między branchami
if [ $# -eq 1 ]; then
    git merge $1 --no-ff --no-edit
    exit 0
else
    echo "Podaj branch do zmergowania."
    exit 1
fi
