#!/bin/bash
# core.sh - 核心函数库

# 加载.env配置文件
load_env() {
    local script_dir="$(get_script_dir)"
    local env_file="${script_dir}/.env"

    if [[ ! -f "$env_file" ]]; then
        log "警告: .env文件不存在，请从.env.example复制并配置" "WARN"
        return 1
    fi

    # 读取.env文件
    # 跳过注释和空行
    while IFS= read -r line || [[ -n "$line" ]]; do
        # 跳过注释和空行
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$line" ]]; then
            continue
        fi

        # 导出环境变量
        if [[ "$line" =~ ^[[:space:]]*([A-Za-z0-9_]+)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # 移除value两端的引号
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"

            export "$key=$value"
        fi
    done < "$env_file"

    return 0
}

# 获取providers目录
get_providers_dir() {
    local script_dir="$(get_script_dir)"
    echo "${script_dir}/providers"
}

# 加载所有供应商插件
load_providers() {
    local providers_dir="$(get_providers_dir)"

    if [[ ! -d "$providers_dir" ]]; then
        log "错误: providers目录不存在: $providers_dir" "ERROR"
        return 1
    fi

    # 加载所有.sh文件
    for provider_file in "$providers_dir"/*.sh; do
        if [[ -f "$provider_file" ]]; then
            source "$provider_file"
            log "加载供应商插件: $(basename "$provider_file")" "DEBUG"
        fi
    done

    return 0
}

# 获取启用的供应商列表
get_enabled_providers() {
    local providers=()

    # 检查每个已知的供应商
    # 注意：这里需要手动列出所有可能的供应商名称
    # 或者可以通过扫描providers目录自动发现
    # 注意：88code对应的环境变量前缀是CODE88

    local known_providers=("rightcode" "code88" "xiaohu")

    for provider in "${known_providers[@]}"; do
        # 将provider名称转为大写并检查ENABLED变量
        local provider_upper=$(echo "$provider" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
        local enabled_var="${provider_upper}_ENABLED"

        # 获取环境变量的值
        local enabled="${!enabled_var}"

        if [[ "$enabled" == "true" ]] || [[ "$enabled" == "1" ]]; then
            providers+=("$provider")
        fi
    done

    # 输出启用的供应商列表（以空格分隔）
    echo "${providers[@]}"
}

# 获取供应商的token
get_provider_token() {
    local provider="$1"

    # 将provider名称转为大写
    local provider_upper=$(echo "$provider" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
    local token_var="${provider_upper}_TOKEN"

    # 获取token值
    echo "${!token_var}"
}

# 获取供应商的额外配置
get_provider_config() {
    local provider="$1"
    local config_key="$2"

    # 将provider名称转为大写
    local provider_upper=$(echo "$provider" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
    local config_var="${provider_upper}_${config_key}"

    # 获取配置值
    echo "${!config_var}"
}

# 调用供应商的display_name函数
call_provider_display_name() {
    local provider="$1"

    # 构建函数名
    local func_name="provider_${provider}_display_name"

    # 检查函数是否存在
    if ! declare -f "$func_name" &>/dev/null; then
        log "错误: 供应商 $provider 未实现 $func_name 函数" "ERROR"
        echo ""
        return 1
    fi

    # 调用函数
    "$func_name"
}

# 调用供应商的fetch函数
call_provider_fetch() {
    local provider="$1"

    # 构建函数名
    local func_name="provider_${provider}_fetch"

    # 检查函数是否存在
    if ! declare -f "$func_name" &>/dev/null; then
        log "错误: 供应商 $provider 未实现 $func_name 函数" "ERROR"
        echo '[]'
        return 1
    fi

    # 获取token和其他配置
    local token=$(get_provider_token "$provider")

    if [[ -z "$token" ]]; then
        log "错误: 供应商 $provider 的token未配置" "ERROR"
        echo '[]'
        return 1
    fi

    # 调用函数
    "$func_name" "$token"
}

# 更新单个供应商的数据
update_provider() {
    local provider="$1"

    log "开始更新供应商: $provider" "INFO"

    # 1. 获取显示名称
    local display_name=$(call_provider_display_name "$provider")

    if [[ -z "$display_name" ]]; then
        log "错误: 无法获取供应商 $provider 的显示名称" "ERROR"
        return 1
    fi

    # 2. 调用fetch获取原始数据
    local raw_subscriptions=$(call_provider_fetch "$provider")
    local fetch_exit=$?
    local has_error="false"

    # 检查是否有错误发生
    if [[ $fetch_exit -ne 0 ]]; then
        log "警告: 供应商 $provider 获取数据失败，退出码: $fetch_exit" "WARN"
        has_error="true"
        # 即使出错也继续，使用空数据或旧缓存
        if [[ -z "$raw_subscriptions" ]] || [[ "$raw_subscriptions" == "[]" ]]; then
            raw_subscriptions="[]"
        fi
    fi

    if [[ -z "$raw_subscriptions" ]] || [[ "$raw_subscriptions" == "[]" ]]; then
        log "警告: 供应商 $provider 返回空数据" "WARN"
        # 如果数据为空，标记为错误（除非已经标记了）
        if [[ "$has_error" == "false" ]]; then
            has_error="true"
        fi
    fi

    # 3. 处理订阅数据（计算消耗、检测充值、记录历史）
    local processed_subscriptions=""

    # 如果获取失败，优先使用缓存中的订阅数据（保持显示旧额度）
    if [[ "$has_error" == "true" ]]; then
        local cached_provider
        cached_provider="$(get_cached_provider "$provider")"
        if [[ -n "$cached_provider" ]] && [[ "$cached_provider" != "{}" ]] && [[ "$cached_provider" != "null" ]]; then
            processed_subscriptions="$(echo "$cached_provider" | jq -c '.subscriptions // []')"
        fi
    fi

    # 正常情况下才处理最新数据；如无缓存则回退为空数组
    if [[ -z "$processed_subscriptions" ]]; then
        if [[ "$raw_subscriptions" == "[]" ]]; then
            processed_subscriptions="[]"
        else
            processed_subscriptions=$(process_provider_subscriptions "$provider" "$raw_subscriptions")
        fi
    fi

    # 4. 构建provider缓存数据
    local provider_data=$(build_provider_cache "$provider" "$display_name" "$processed_subscriptions" "$has_error")

    # 5. 更新到current.json
    update_provider_in_cache "$provider" "$provider_data"

    log "完成更新供应商: $provider (has_error=$has_error)" "INFO"
    return 0
}

# 更新所有启用的供应商
update_all_providers() {
    local enabled_providers=($(get_enabled_providers))

    if [[ ${#enabled_providers[@]} -eq 0 ]]; then
        log "警告: 没有启用的供应商" "WARN"
        return 1
    fi

    log "开始更新 ${#enabled_providers[@]} 个供应商: ${enabled_providers[*]}" "INFO"

    local success_count=0
    local fail_count=0

    for provider in "${enabled_providers[@]}"; do
        if update_provider "$provider"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done

    log "更新完成: 成功 $success_count, 失败 $fail_count" "INFO"

    return 0
}
