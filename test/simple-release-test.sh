#!/usr/bin/env bash
set -e -o allexport

source ./.env

echo "CI_PROJECT_PATH=${CI_PROJECT_PATH}"
echo "GITLAB_PRIVATE_TOKEN=${GITLAB_PRIVATE_TOKEN}"

bash ./gitlab-dist.sh test/fixtures/demo1.txt test/fixtures/demo
