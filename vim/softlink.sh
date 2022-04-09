#!/bin/bash

_curdir="`dirname $(readlink -f $0)`"
source $_curdir/../lib/common.sh

_ln $_curdir/../vim ~/.vim
_ln $_curdir/.vimrc ~/.vimrc
