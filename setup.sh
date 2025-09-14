#!/usr/bin/env bash

# make sure we have pulled in and updated any submodules
git submodule init
git submodule update

# what directories should be installable by all users including the root user
base=(
    bash
)

# folders that should, or only need to be installed for a local user
useronly=(
    git
    zsh
    completion
    vim
    ghostty
    vscode
    direnv
    claude
)

# run the stow command for the passed in directory ($2) in location $1
stowit() {
    usr=$1
    app=$2
    # -v verbose
    # -R recursive
    # -t target
    stow -v -R -t ${usr} ${app}
}

for app in ${base[@]}; do
    stowit "${HOME}" $app
done

echo ""
echo "Stowing apps for user: ${whoami}"

for app in ${useronly[@]}; do
    if [[ "$(whoami)" != "root" ]]; then
        stowit "${HOME}" $app
    fi
done

echo ""
echo "##### ALL DONE"

