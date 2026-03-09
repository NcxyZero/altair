#!/bin/bash

set -e

# FileSystemWatcher works best on Windows, so we delegate to PowerShell.
exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./watch-sourcemap.ps1
