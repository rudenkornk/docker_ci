#!/usr/bin/env bash

echo $(id --user):$(id --group)
echo $(id --user --name):$(id --group --name)
echo $(id --groups --name)

