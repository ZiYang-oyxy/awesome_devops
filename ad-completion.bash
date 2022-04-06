#!/bin/bash
# refer to https://github.com/iridakos/bash-completion-tutorial

_mycmd_compgen_filenames() {
    local cur="$1"

    # Files, excluding directories:
    grep -v -F -f <(compgen -d -P ^ -S '$' -- "$cur") \
        <(compgen -f -P ^ -S '$' -- "$cur") |
        sed -e 's/^\^//' -e 's/\$$/ /'

    # Directories:
    compgen -d -S / -- "$cur"
}

_ad()
{
    case "$COMP_CWORD" in
        1)
            tools=`ls ~/.awesome_devops/tools 2> /dev/null`
            ext_tools=`ls ~/.awesome_devops/ext_tools 2>/dev/null`
            COMPREPLY=($(compgen -W "help upgrade tree put tput get dput dget deploy $tools $ext_tools" "${COMP_WORDS[1]}"))
            ;;
        2)
            case ${COMP_WORDS[1]} in
                *)
                    COMPREPLY=($(_mycmd_compgen_filenames "${COMP_WORDS[2]}"))
                    ;;
            esac
            ;;
        *)
            return
            ;;
    esac
}

complete -F _ad ad
