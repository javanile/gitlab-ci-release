#!/usr/bin/env bash
set -e

git config credential.helper 'cache --timeout=3600'
git add .
git commit -am "Release test" && true
git push

if [[ ! -d "test/fixtures/gitlab-dist" ]]; then
    git clone https://gitlab.com/javanile/gitlab-dist.git test/fixtures/gitlab-dist
fi

cd test/fixtures/gitlab-dist

git pull
date > RELEASE_TEST
git add .
git commit -am "run test"
git push

echo "[INFO] Visit this page <https://gitlab.com/javanile/gitlab-dist/-/jobs>"
