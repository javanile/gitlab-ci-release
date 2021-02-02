#!/usr/bin/env bash
set -e -o allexport

echo "====[ Environment ]===="
source ./.env
echo "CI_PROJECT_PATH=${CI_PROJECT_PATH}"
echo "GITLAB_PRIVATE_TOKEN=${GITLAB_PRIVATE_TOKEN}"

echo ""
echo "====[ Testing '${1}' ]==="