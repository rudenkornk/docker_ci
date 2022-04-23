#!/usr/bin/env bash

set -x

fc-cache -f
mktextfm larm1000
mktextfm larm1200

export DRAWIO_CMD="xvfb-run drawio"
echo "export DRAWIO_CMD=\"$DRAWIO_CMD\"" >> ~/.profile

