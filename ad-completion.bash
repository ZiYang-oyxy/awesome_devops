#!/bin/bash
# refer to
# 1. https://github.com/iridakos/bash-completion-tutorial
# 2. https://www.gnu.org/software/bash/manual/html_node/Programmable-Completion-Builtins.html#Programmable-Completion-Builtins

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
                deploy)
                    plugins=`ls ~/.awesome_devops/plugins`
                    COMPREPLY=($(compgen -W "$plugins" "${COMP_WORDS[2]}"))
                    ;;
                *)
                    # 有目录工具，目录与工具名必须同名，直接执行
                    if [[ -f ~/.awesome_devops/tools/${COMP_WORDS[1]}/${COMP_WORDS[1]} ]]; then
                        COMPREPLY=($(_mycmd_compgen_filenames "${COMP_WORDS[2]}"))
                    elif [[ -f ~/.awesome_devops/ext_tools/${COMP_WORDS[1]}/${COMP_WORDS[1]} ]]; then
                        COMPREPLY=($(_mycmd_compgen_filenames "${COMP_WORDS[2]}"))
                    # 有目录工具，目录与工具名不同名，一般是一个工具集，展示命令列表，或直接执行
                    elif [[ -d ~/.awesome_devops/tools/${COMP_WORDS[1]} ]]; then
                        executable=`(cd ~/.awesome_devops/tools/${COMP_WORDS[1]}; \
                            find ./ -maxdepth 1 -executable -type f -printf '%f\n')`
                        COMPREPLY=($(compgen -W "$executable" "${COMP_WORDS[2]}"))
                    elif [[ -d ~/.awesome_devops/ext_tools/${COMP_WORDS[1]} ]]; then
                        executable=`(cd ~/.awesome_devops/ext_tools/${COMP_WORDS[1]}; \
                            find ./ -maxdepth 1 -executable -type f -printf '%f\n')`
                        COMPREPLY=($(compgen -W "$executable" "${COMP_WORDS[2]}"))
                    else
                        # 其他工具，直接执行
                        COMPREPLY=($(_mycmd_compgen_filenames "${COMP_WORDS[2]}"))
                    fi
                    ;;
            esac
            ;;
        *)
            COMPREPLY=($(_mycmd_compgen_filenames "${COMP_WORDS[$COMP_CWORD]}"))
            ;;
    esac

    # macos默认的bash版本太老，不支持compopt
    if type compopt > /dev/null 2>&1 && [[ $COMPREPLY == */ ]]; then
        compopt -o nospace
    fi
}

complete -F _ad ad

# 让bash命令行直接能使用cecho，不需要额外带上ad
cecho(){
    ~/.awesome_devops/tools/cecho "$@"
}
