#!/bin/bash
set -e

# https://stackoverflow.com/a/48708760/4754613
function is_git_submodule() {
    local module_name 

    module_path="$(git rev-parse --show-toplevel 2> /dev/null)"

    # List all the submodule paths for the parent repo and look for our module's path
    (cd "${module_path}/.." && git submodule --quiet foreach 'echo $toplevel/$path' 2> /dev/null) | \
        grep --quiet --line-regexp --fixed-strings "$module_path"
}

if ! is_git_submodule; then
    echo "command needs to be run within a git submodule"
    exit 1
fi

case $(basename "$(pwd)") in
    idm|kweb|lico)
        branch=master
        ;;
    *)
        branch=main
        ;;
esac

git fetch
git checkout $branch
git pull origin $branch