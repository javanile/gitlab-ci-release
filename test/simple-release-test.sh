#!/usr/bin/env bash
set -e -o allexport

source ./test/bootstrap.sh $0

bash ./gitlab-dist.sh --tag demo2 test/fixtures/demo1.txt test/fixtures/demo
