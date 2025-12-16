#!/bin/bash

source ~/.awesome_devops/config

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

_ln(){
    if [[ -e $2 ]]; then
        rm -rf $2.bak
        mv -f $2 $2.bak
    fi
    ln -sf $1 $2
}

cecho(){
    ~/.awesome_devops/tools/cecho "$@"
}
