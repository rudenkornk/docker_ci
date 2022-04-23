#!/usr/bin/env bash

if [[ ! -z "$CI_UID" ]]; then
    if [[ "$CI_UID" == "0" ]]; then
        echo "ERROR: CI user must not be root!"
        exit 1
    fi
    # No need to change ownership in home dir since usermod does it itself
    usermod --uid $CI_UID ci_user
fi

if [[ ! -z "$CI_GID" ]]; then
    if [[ "$CI_GID" == "0" ]]; then
        echo "ERROR: CI group id must not be root!"
        exit 1
    fi
    groupmod --gid $CI_GID ci_user
    chgrp --recursive $CI_GID /home/ci_user
fi

# Drop privileges and execute next container command, or 'bash' if not specified.
sudo deluser --quiet ci_user sudo
source /home/ci_user/.profile
if [[ $# -gt 0 ]]; then
    exec sudo --preserve-env --user=$USER -- /home/ci_user/entrypoint_continue.sh $@
else
    exec sudo --preserve-env --user=$USER -- bash
fi

