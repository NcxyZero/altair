#!/bin/bash

set -e
echo "Starting update..."
rm -f wally.lock
wally install
rojo sourcemap default.project.json --output sourcemap.json
wally-package-types --sourcemap sourcemap.json Packages/
./generate-reflex-types.sh
