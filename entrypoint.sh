#!/usr/bin/env bash

exec sudo --preserve-env USER=$(id --user --name) /home/ci_user/entrypoint_usermod.sh $@

