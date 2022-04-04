#!/bin/bash
# refer to https://github.com/iridakos/bash-completion-tutorial

_ad()
{
    if [ "${#COMP_WORDS[@]}" != "2" ]; then
        return
    fi

    tools=`ls ~/.awesome_devops/tools 2> /dev/null`
    ext_tools=`ls ~/.awesome_devops/ext_tools 2>/dev/null`
    COMPREPLY=($(compgen -W "help upgrade tree put tput get dput dget deploy $tools $ext_tools" "${COMP_WORDS[1]}"))
}

complete -F _ad ad
