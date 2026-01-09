#!/bin/bash
# utils.sh - 工具函数库

# 获取脚本根目录
get_script_dir() {
    local source="${BASH_SOURCE[0]}"
    while [ -h "$source" ]; do
        local dir="$( cd -P "$( dirname "$source" )" && pwd )"
        source="$(readlink "$source")"
        [[ $source != /* ]] && source="$dir/$source"
    done
    SCRIPT_DIR="$( cd -P "$( dirname "$source" )/.." && pwd )"
    echo "$SCRIPT_DIR"
}

# 检查依赖
check_dependencies() {
    local deps=("jq" "curl" "bc")
    local missing=()

    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo "错误: 缺少以下依赖: ${missing[*]}" >&2
        echo "请安装缺少的依赖后再运行此脚本" >&2
        return 1
    fi

    return 0
}

# 跨平台获取文件修改时间 (从xiaohu脚本迁移)
get_mtime() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo 0
        return 1
    fi

    # 尝试BSD stat (macOS)
    if mtime=$(stat -f %m "$file" 2>/dev/null); then
        if [[ "$mtime" =~ ^[0-9]+$ ]]; then
            echo "$mtime"
            return 0
        fi
    fi

    # 尝试GNU stat (Linux)
    if mtime=$(stat -c %Y "$file" 2>/dev/null); then
        if [[ "$mtime" =~ ^[0-9]+$ ]]; then
            echo "$mtime"
            return 0
        fi
    fi

    echo 0
    return 1
}

# 确保目录存在
ensure_dir() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" 2>/dev/null || {
            echo "错误: 无法创建目录 $dir" >&2
            return 1
        }
    fi

    return 0
}

# 日志函数
log() {
    local level="${2:-INFO}"
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $message" >&2
}

# 日志到文件
log_to_file() {
    local message="$1"
    local level="${2:-INFO}"
    local log_file="${3:-}"

    if [[ -z "$log_file" ]]; then
        log "$message" "$level"
        return
    fi

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$log_file"
}

# 安全的数值比较（使用bc）
compare_numbers() {
    local num1="$1"
    local op="$2"
    local num2="$3"

    # 处理空值
    num1="${num1:-0}"
    num2="${num2:-0}"

    case "$op" in
        "gt"|">")
            result=$(echo "$num1 > $num2" | bc -l)
            ;;
        "lt"|"<")
            result=$(echo "$num1 < $num2" | bc -l)
            ;;
        "eq"|"==")
            result=$(echo "$num1 == $num2" | bc -l)
            ;;
        "ge"|">=")
            result=$(echo "$num1 >= $num2" | bc -l)
            ;;
        "le"|"<=")
            result=$(echo "$num1 <= $num2" | bc -l)
            ;;
        *)
            echo "错误: 不支持的比较操作符 $op" >&2
            return 2
            ;;
    esac

    if [[ "$result" == "1" ]]; then
        return 0
    else
        return 1
    fi
}

# 格式化数字（保留2位小数）
format_number() {
    local num="$1"
    local decimals="${2:-2}"

    # 处理空值
    if [[ -z "$num" ]] || [[ "$num" == "null" ]]; then
        printf "%.${decimals}f" 0
        return
    fi

    # 使用bc进行格式化
    printf "%.${decimals}f" "$num"
}

# 原子写入文件（先写临时文件，再移动）
atomic_write() {
    local content="$1"
    local target_file="$2"
    local temp_file="${target_file}.tmp.$$"

    # 写入临时文件
    echo "$content" > "$temp_file" || {
        echo "错误: 无法写入临时文件 $temp_file" >&2
        return 1
    }

    # 原子移动
    mv "$temp_file" "$target_file" || {
        echo "错误: 无法移动文件到 $target_file" >&2
        rm -f "$temp_file"
        return 1
    }

    return 0
}

# 获取当前时间戳
get_timestamp() {
    date +%s
}

# 获取格式化的日期时间
get_datetime() {
    if [[ -n "${USAGE_TZ:-}" ]]; then
        TZ="$USAGE_TZ" date '+%Y-%m-%d %H:%M:%S'
    else
        date '+%Y-%m-%d %H:%M:%S'
    fi
}

# 获取当前日期
get_date() {
    if [[ -n "${USAGE_TZ:-}" ]]; then
        TZ="$USAGE_TZ" date '+%Y-%m-%d'
    else
        date '+%Y-%m-%d'
    fi
}

# 获取指定日期的0点时间戳（支持USAGE_TZ）
get_day_start_timestamp() {
    local date_str="$1"
    local ts=""

    if [[ -n "${USAGE_TZ:-}" ]]; then
        if ts=$(TZ="$USAGE_TZ" date -j -f "%Y-%m-%d %H:%M:%S" "${date_str} 00:00:00" "+%s" 2>/dev/null); then
            echo "$ts"
            return 0
        fi
        if ts=$(TZ="$USAGE_TZ" date -d "${date_str} 00:00:00" "+%s" 2>/dev/null); then
            echo "$ts"
            return 0
        fi
    else
        if ts=$(date -j -f "%Y-%m-%d %H:%M:%S" "${date_str} 00:00:00" "+%s" 2>/dev/null); then
            echo "$ts"
            return 0
        fi
        if ts=$(date -d "${date_str} 00:00:00" "+%s" 2>/dev/null); then
            echo "$ts"
            return 0
        fi
    fi

    echo 0
    return 1
}
