#!/usr/bin/env bash

##
# gitlab-dist.sh
#
# Copyright (c) 2020 Francesco Bianco <bianco@javanile.org>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
##

set -e

VERSION=0.1.0
GITLAB_PROJECTS_API_URL="https://gitlab.com/api/v4/projects"
CI_CURRENT_PROJECT_SLUG="${CI_PROJECT_PATH//\//%2F}"
CI_CURRENT_BRANCH="${CI_COMMIT_BRANCH}"

usage () {
    echo "Usage: ./gitlab-dist.sh [OPTION]... [FILE]..."
    echo ""
    echo "Store files to GitLab repository to perform a releases storage."
    echo ""
    echo "List of available options"
    echo "  -t, --tag TAG          Set release tag name"
    echo "  -b, --branch BRANCH    Set branch for releases store"
    echo "  -l, --layout LAYOUT    Set release tag name"
    echo "  -h, --help             Display this help and exit"
    echo "  -v, --version          Display current version"
    echo ""
    echo "Documentation can be found at https://github.com/javanile/lcov.sh"
}

tag=latest
branch=main
layout=default-release-storage
options=$(getopt -n gitlab-dist.sh -o l:t:b:vh -l layout:,tag:,branch:,version,help -- "$@")

eval set -- "${options}"

while true; do
    case "$1" in
        -t|--tag) shift; tag=$1; ;;
        -b|--branch) shift; branch=$1; ;;
        -l|--layout) shift; layout=$1 ;;
        -v|--version) echo "GitLab Dist [0.0.1] - by Francesco Bianco <bianco@javanile.org>"; exit ;;
        -h|--help) usage; exit ;;
        --) shift; break ;;
    esac
    shift
done

##
# Print-out error message and exit.
##
error() {
    echo "ERROR --> $1"
    exit 1
}

##
# Call CURL POST request to GitLab API.
##
ci_curl_get() {
    CI_CURL_HTTP_STATUS=200
    local url="${GITLAB_PROJECTS_API_URL}/${CI_CURRENT_PROJECT_SLUG}/$1"

    echo "GET ${url}"
    curl -XGET -fsSL ${url} \
         -H "Content-Type: application/json" \
         -H "PRIVATE-TOKEN: ${GITLAB_PRIVATE_TOKEN}" 2> CI_CURL_ERROR && true

    [[ "$?" = "22" ]] && ci_curl_ignore_error || ci_curl_error
}

##
# Call CURL POST request to GitLab API.
##
ci_curl_post() {
    CI_CURL_HTTP_STATUS=200
    local url="${GITLAB_PROJECTS_API_URL}/${CI_CURRENT_PROJECT_SLUG}/$1"

    echo "POST ${url}"
    curl -XPOST -fsSL ${url} \
         -H "Content-Type: application/json" \
         -H "PRIVATE-TOKEN: ${GITLAB_PRIVATE_TOKEN}" \
         --data "$2" 2> CI_CURL_ERROR && true

    [[ "$?" = "22" ]] && ci_curl_ignore_error || ci_curl_error
}

##
# Call CURL POST request to GitLab API.
##
ci_curl_put() {
    CI_CURL_HTTP_STATUS=200
    local url="${GITLAB_PROJECTS_API_URL}/${CI_CURRENT_PROJECT_SLUG}/$1"

    echo "PUT ${url}"
    curl -XPUT -fsSL ${url} \
         -H "Content-Type: application/json" \
         -H "PRIVATE-TOKEN: ${GITLAB_PRIVATE_TOKEN}" \
         --data "$2" 2> CI_CURL_ERROR && true

    [[ "$?" = "22" ]] && ci_curl_ignore_error || ci_curl_error
}

##
# Call CURL POST request to GitLab API.
##
ci_curl_ignore_error() {
    cat CI_CURL_ERROR
    CI_CURL_HTTP_STATUS=$(awk 'END {print $NF}' CI_CURL_ERROR)
    echo "CI_CURL_HTTP_STATUS=${CI_CURL_HTTP_STATUS}"
    rm CI_CURL_ERROR
    echo "Exit was ignored by idempotent mode"
}

##
# Call CURL POST request to GitLab API.
##
ci_curl_error() {
    cat CI_CURL_ERROR
    rm CI_CURL_ERROR
    exit 1
}

##
# curl -fsSL ...
##
dist_upload_action() {
    local file_path=${CI_PROJECT_PATH:-ci}/${tag:-latest}
    #echo "ARGS ${@} - ${tag} - ${file_path}"
    local url=${GITLAB_PROJECTS_API_URL}/${GITLAB_RELEASES_STORE//\//%2F}/repository/commits
    [[ -n "$3" ]] && file_path="${file_path=}/$3"
    file_path="${file_path}/$(basename "$2")"
    file_base64="$(mktemp -t dist-upload-XXXXXXXXXX)"
    base64 $2 > ${file_base64}

    #echo "Release storage: ${url}"
    echo " - Reading '$2'"
    [[ -f "$2" ]] || echo "File not found: $2"
    echo -n " - Uploading '${file_path}' ($1) "
    curl --request POST \
         --form "branch=${branch}" \
         --form "commit_message=fileupload" \
         --form "start_branch=${branch}" \
         --form "actions[][action]=$1" \
         --form "actions[][file_path]=${file_path}" \
         --form "actions[][content]=<${file_base64}" \
         --form "actions[][encoding]=base64" \
         --header "PRIVATE-TOKEN: ${GITLAB_PRIVATE_TOKEN}" \
         -fsSL "${url}" > /dev/null && echo "(done)"
}

##
#
##
dist_upload_file() {
    dist_upload_action update "$1" "$2" || dist_upload_action create "$1" "$2"
}

##
#
##
dist_upload_dir() {
  for path in $1/*; do
    prefix=$(basename "$1")
    [[ -n "$2" ]] && prefix="$2/${prefix}"
    if [[ -d "${path}" ]]; then
      echo " - Directory '${path}'"
      dist_upload_dir "${path}" "${prefix}"
    elif [[ -f "${path}" ]]; then
      echo " - File '${path}' => ${prefix}"
      dist_upload_file "${path}" "${prefix}"
    else
      echo " - Ignored '${path}'"
    fi
  done
}

##
# Create a new branch if not exists based on current branch.
#
# Ref: https://docs.gitlab.com/ee/api/branches.html#create-repository-branch
##
ci_create_branch () {
    [[ -z "$1" ]] && error "Missing new branch name"
    [[ -z "$2" ]] && local ref="${CI_CURRENT_BRANCH}" || local ref="$2"

    ci_curl_post "repository/branches?branch=$1&ref=${ref}"
}

##
# Create a new file if not exists on current branch.
#
# Ref: https://docs.gitlab.com/ee/api/branches.html#create-repository-branch
##
ci_create_file () {
    [[ -z "$1" ]] && error "Missing file name"
    [[ -z "$2" ]] && error "Missing file content"
    #[[ -z "$3" ]] && error "Missing branch name"

    ci_curl_post "repository/files/$1" "{
        \"branch\": \"${CI_CURRENT_BRANCH}\",
        \"content\": \"$2\",
        \"commit_message\": \"Create file $1\"
    }"
}

##
# Exit with a message
##
ci_fail() {
    echo "================"
    echo ">>>   FAIL   <<<"
    echo "================"
    echo "MESSAGE: $1"
    exit 1
}

##
# Print-out useful information.
##
ci_info() {
    echo "CI_CURRENT_PROJECT_SLUG=${CI_CURRENT_PROJECT_SLUG}"
    echo "CI_CURRENT_BRANCH=${CI_CURRENT_BRANCH}"
}

##
# Main function
##
main () {
  [[ -z "${CI_PROJECT_PATH}" ]] && error "Missing or empty CI_PROJECT_PATH variable."
  [[ -z "${GITLAB_RELEASES_STORE}" ]] && error "Missing or empty GITLAB_RELEASES_STORE variable."
  [[ -z "${GITLAB_PRIVATE_TOKEN}" ]] && error "Missing or empty GITLAB_PRIVATE_TOKEN variable."

  echo "Tag '${tag}'"
  for path in "$@"; do
    if [[ -d "${path}" ]]; then
      echo " - Directory '${path}'"
      dist_upload_dir "${path}"
    elif [[ -f "${path}" ]]; then
      echo " - File '${path}'"
      dist_upload_file "${path}"
    else
      echo " - Ignored '${path}'"
    fi
  done
}

## Entrypoint
main "$@"
