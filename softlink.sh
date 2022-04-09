#!/bin/bash

_curdir="`dirname $(readlink -f $0)`"
source $_curdir/lib/common.sh

_ln $_curdir/../awesome_devops ~/.awesome_devops
