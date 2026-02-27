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

_ad_completion_root() {
    if [[ -n "$AD_COMPLETION_ROOT" ]] && [[ -d "$AD_COMPLETION_ROOT" ]]; then
        echo "$AD_COMPLETION_ROOT"
        return 0
    fi

    _self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
    if [[ -n "$_self_dir" ]] && [[ -f "$_self_dir/ad" ]]; then
        echo "$_self_dir"
        return 0
    fi

    echo "$HOME/.awesome_devops"
}

_ad_external_root() {
    _root="$1"

    if [[ -n "$AD_EXTERNAL_DIR" ]] && [[ -d "$AD_EXTERNAL_DIR/awesome_devops" ]]; then
        echo "$AD_EXTERNAL_DIR/awesome_devops"
        return 0
    fi

    if [[ -d "$_root/../ad_external/awesome_devops" ]]; then
        echo "$_root/../ad_external/awesome_devops"
        return 0
    fi

    echo ""
}

_ad_merge_dir_entries() {
    _root="$1"
    _ext_root="$2"
    _relative_path="$3"

    {
        ls "$_root/$_relative_path" 2>/dev/null
        if [[ -n "$_ext_root" ]]; then
            ls "$_ext_root/$_relative_path" 2>/dev/null
        fi
    } | awk "NF" | sort -u
}

_ad_resolve_tool_file() {
    _root="$1"
    _ext_root="$2"
    _tool_name="$3"

    if [[ -f "$_root/tools/$_tool_name" ]]; then
        echo "$_root/tools/$_tool_name"
        return 0
    fi
    if [[ -f "$_root/ext_tools/$_tool_name" ]]; then
        echo "$_root/ext_tools/$_tool_name"
        return 0
    fi
    if [[ -n "$_ext_root" ]] && [[ -f "$_ext_root/tools/$_tool_name" ]]; then
        echo "$_ext_root/tools/$_tool_name"
        return 0
    fi
    if [[ -n "$_ext_root" ]] && [[ -f "$_ext_root/ext_tools/$_tool_name" ]]; then
        echo "$_ext_root/ext_tools/$_tool_name"
        return 0
    fi
    return 1
}

_ad_resolve_named_tool_dir() {
    _root="$1"
    _ext_root="$2"
    _tool_name="$3"

    if [[ -f "$_root/tools/$_tool_name/$_tool_name" ]]; then
        echo "$_root/tools/$_tool_name"
        return 0
    fi
    if [[ -f "$_root/ext_tools/$_tool_name/$_tool_name" ]]; then
        echo "$_root/ext_tools/$_tool_name"
        return 0
    fi
    if [[ -n "$_ext_root" ]] && [[ -f "$_ext_root/tools/$_tool_name/$_tool_name" ]]; then
        echo "$_ext_root/tools/$_tool_name"
        return 0
    fi
    if [[ -n "$_ext_root" ]] && [[ -f "$_ext_root/ext_tools/$_tool_name/$_tool_name" ]]; then
        echo "$_ext_root/ext_tools/$_tool_name"
        return 0
    fi
    return 1
}

_ad_resolve_tool_suite_dir() {
    _root="$1"
    _ext_root="$2"
    _tool_name="$3"

    if [[ -d "$_root/tools/$_tool_name" ]]; then
        echo "$_root/tools/$_tool_name"
        return 0
    fi
    if [[ -d "$_root/ext_tools/$_tool_name" ]]; then
        echo "$_root/ext_tools/$_tool_name"
        return 0
    fi
    if [[ -n "$_ext_root" ]] && [[ -d "$_ext_root/tools/$_tool_name" ]]; then
        echo "$_ext_root/tools/$_tool_name"
        return 0
    fi
    if [[ -n "$_ext_root" ]] && [[ -d "$_ext_root/ext_tools/$_tool_name" ]]; then
        echo "$_ext_root/ext_tools/$_tool_name"
        return 0
    fi
    return 1
}

_ad()
{
    local root
    local ext_root
    root="$(_ad_completion_root)"
    ext_root="$(_ad_external_root "$root")"

    case "$COMP_CWORD" in
        1)
            tools="$(_ad_merge_dir_entries "$root" "$ext_root" tools)"
            ext_tools="$(_ad_merge_dir_entries "$root" "$ext_root" ext_tools)"
            COMPREPLY=($(compgen -W "help upgrade uninstall tree publish doctor put tput get dput dgput dget deploy $tools $ext_tools" "${COMP_WORDS[1]}"))
            ;;
        2)
            case ${COMP_WORDS[1]} in
                deploy)
                    plugins="$(_ad_merge_dir_entries "$root" "$ext_root" plugins)"
                    COMPREPLY=($(compgen -W "$plugins" "${COMP_WORDS[2]}"))
                    ;;
                publish)
                    COMPREPLY=($(compgen -W "-f -h" "${COMP_WORDS[2]}"))
                    ;;
                doctor)
                    COMPREPLY=($(compgen -W "env help -h --help" "${COMP_WORDS[2]}"))
                    ;;
                *)
                    # 有目录工具，目录与工具名必须同名，直接执行
                    if tool_path="$(_ad_resolve_tool_file "$root" "$ext_root" "${COMP_WORDS[1]}")"; then
                        COMPREPLY=($(_mycmd_compgen_filenames "${COMP_WORDS[2]}"))
                    elif tool_dir="$(_ad_resolve_named_tool_dir "$root" "$ext_root" "${COMP_WORDS[1]}")"; then
                        COMPREPLY=($(_mycmd_compgen_filenames "${COMP_WORDS[2]}"))
                    # 有目录工具，目录与工具名不同名，一般是一个工具集，展示命令列表，或直接执行
                    elif suite_dir="$(_ad_resolve_tool_suite_dir "$root" "$ext_root" "${COMP_WORDS[1]}")"; then
                        executable="$(find "$suite_dir" -maxdepth 1 -type f -perm -111 2>/dev/null | sed "s#.*/##")"
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

export PATH=~/bin:$PATH
if type brew > /dev/null 2>&1; then
    brew_prefix=$(brew --prefix)
    export PATH=$brew_prefix/opt/coreutils/libexec/gnubin:$PATH
    export PATH=$brew_prefix/opt/findutils/libexec/gnubin:$PATH
    export PATH=$brew_prefix/opt/grep/libexec/gnubin/:$PATH
fi
