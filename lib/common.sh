#!/bin/bash

export PUTURL="http://Awesome:Devops@10.145.17.12:8889"
export GETURL="http://Awesome:Devops@10.145.17.12:8890"

cecho() {
  local code="\033["
  case "$1" in
    black  | bk) color="${code}0;30m";;
    red    |  r) color="${code}0;31m";;
    green  |  g) color="${code}0;32m";;
    yellow |  y) color="${code}0;33m";;
    blue   |  b) color="${code}0;34m";;
    purple |  p) color="${code}0;35m";;
    cyan   |  c) color="${code}0;36m";;
    gray   | gr) color="${code}0;30m";;
    *) local text="$1"
  esac
  [ -z "$text" ] && local text="$color$2${code}0m"
  echo -e "$text"
}

_cecho() {
  local code="\033["
  case "$1" in
    black  | bk) color="${code}0;30m";;
    red    |  r) color="${code}0;31m";;
    green  |  g) color="${code}0;32m";;
    yellow |  y) color="${code}0;33m";;
    blue   |  b) color="${code}0;34m";;
    purple |  p) color="${code}0;35m";;
    cyan   |  c) color="${code}0;36m";;
    gray   | gr) color="${code}0;30m";;
    *) local text="$1"
  esac
  [ -z "$text" ] && local text="$color$2${code}0m"
  echo -e "$text\c"
}

cecho_test() {
	ret="test"
	cecho bk "bk $ret"
	cecho r "r $ret"
	cecho g "g $ret"
	cecho y "y $ret"
	cecho b "b $ret"
	cecho p "p $ret"
	cecho c "c $ret"
	cecho gr "gr $ret"
}

curdir(){
    dirname $(readlink -f $0)
}

# Log the given message at the given level. All logs are written to stderr with a timestamp.
function log {
  local -r level="$1"
  local -r message="$2"
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "${timestamp}|${level}|${BASH_SOURCE[2]}:${BASH_LINENO[1]}|${message}"
}

# Log the given message at INFO level. All logs are written to stderr with a timestamp.
function log_info {
  local -r message="$1"
  log "INFO" "$message"
}

# Log the given message at WARN level. All logs are written to stderr with a timestamp.
function log_warn {
  local -r message="$1"
  log "WARN" "$message"
}

# Log the given message at ERROR level. All logs are written to stderr with a timestamp.
function log_error {
  local -r message="$1"
  log "ERROR" "$message"
}

function ssh_retry {
    ssh -v -o ConnectTimeout=5 -o ConnectionAttempts=6 "$@"
}
