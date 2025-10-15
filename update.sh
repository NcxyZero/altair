#!/bin/bash

echo "Starting update..."
rm wally.lock
wally install
rojo sourcemap default.project.json --output sourcemap.json
wally-package-types --sourcemap sourcemap.json Packages/
