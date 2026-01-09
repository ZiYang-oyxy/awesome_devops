#!/bin/bash
# code88.sh - 88Code供应商插件
# 注意：文件名为code88，因为bash变量不能以数字开头

# 返回供应商显示名称
provider_code88_display_name() {
    echo "8"
}

# API请求辅助函数
_code88_api_request() {
    local endpoint="$1"
    local token="$2"
    local tenant_id="$3"

    local base_url="https://www.88code.org/admin-api/cc-admin"
    local url="${base_url}${endpoint}"

    local temp_file=$(mktemp)
    local http_code=$(curl -s -w "%{http_code}" -o "$temp_file" \
         -H "Authorization: Bearer $token" \
         -H "tenant-id: $tenant_id" \
         -H "Content-Type: application/json" \
         "$url")
    local curl_exit=$?
    local response=$(cat "$temp_file")
    rm -f "$temp_file"

    # 检查curl是否执行成功
    if [[ $curl_exit -ne 0 ]]; then
        log "错误: 88Code curl请求失败 [$endpoint]，退出码: $curl_exit" "ERROR"
        return 2
    fi

    # 检查HTTP状态码
    if [[ "$http_code" != "200" ]]; then
        log "错误: 88Code API返回HTTP状态码 [$endpoint]: $http_code" "ERROR"
        return 3
    fi

    echo "$response"
}

# 获取Codex Free额度
_code88_get_codex_free() {
    local token="$1"
    local tenant_id="$2"

    local response=$(_code88_api_request "/system/subscription/codex-free-quota" "$token" "$tenant_id")

    # 检查响应
    if [[ -z "$response" ]]; then
        return 1
    fi

    local code=$(echo "$response" | jq -r '.code // -1')

    if [[ "$code" != "0" ]]; then
        log "错误: 88Code Codex Free API返回错误码: $code" "ERROR"
        return 1
    fi

    local remaining=$(echo "$response" | jq -r '.data.remainingQuota // 0')
    local daily=$(echo "$response" | jq -r '.data.dailyQuota // 0')

    # 返回JSON对象
    cat <<EOF
{
  "id": "codex_free",
  "name": "Codex Free",
  "display": "CF",
  "total": $daily,
  "remaining": $remaining,
  "usage_mode": "daily_total"
}
EOF
}

# 获取订阅（FREE和PAYGO）
_code88_get_subscriptions() {
    local token="$1"
    local tenant_id="$2"

    local response=$(_code88_api_request "/system/subscription/my" "$token" "$tenant_id")

    # 检查响应
    if [[ -z "$response" ]]; then
        return 1
    fi

    local code=$(echo "$response" | jq -r '.code // -1')

    if [[ "$code" != "0" ]]; then
        log "错误: 88Code Subscriptions API返回错误码: $code" "ERROR"
        return 1
    fi

    local subscriptions=$(echo "$response" | jq -r '.data // []')

    # 处理FREE订阅
    local free_sub=$(echo "$subscriptions" | jq -r '.[] | select(.subscriptionPlanName == "FREE" and .isActive == true) | .')

    local result_array="["
    local has_items=false

    if [[ -n "$free_sub" ]] && [[ "$free_sub" != "null" ]] && [[ "$free_sub" != "" ]]; then
        local current_credits=$(echo "$free_sub" | jq -r '.currentCredits // 0')
        local credit_limit=$(echo "$free_sub" | jq -r '.subscriptionPlan.creditLimit // 0')

        result_array="$result_array
{
  \"id\": \"free\",
  \"name\": \"FREE Plan\",
  \"display\": \"F\",
  \"total\": $credit_limit,
  \"remaining\": $current_credits
}"
        has_items=true
    fi

    # 处理PAYGO订阅
    local paygo_sub=$(echo "$subscriptions" | jq -r '.[] | select(.subscriptionPlanName == "PAYGO" and .isActive == true) | .')

    if [[ -n "$paygo_sub" ]] && [[ "$paygo_sub" != "null" ]] && [[ "$paygo_sub" != "" ]]; then
        local current_credits=$(echo "$paygo_sub" | jq -r '.currentCredits // 0')
        local credit_limit=$(echo "$paygo_sub" | jq -r '.subscriptionPlan.creditLimit // 0')

        if $has_items; then
            result_array="$result_array,"
        fi

        result_array="$result_array
{
  \"id\": \"paygo\",
  \"name\": \"PAYGO Plan\",
  \"display\": \"P\",
  \"total\": $credit_limit,
  \"remaining\": $current_credits
}"
        has_items=true
    fi

    result_array="$result_array
]"

    if $has_items; then
        echo "$result_array"
    else
        echo "[]"
    fi
}

# 获取88Code余额
provider_code88_fetch() {
    local token="$1"

    # 获取tenant_id配置
    local tenant_id=$(get_provider_config "code88" "TENANT_ID")

    if [[ -z "$tenant_id" ]]; then
        log "错误: 88Code TENANT_ID未配置" "ERROR"
        echo '[]'
        return 1
    fi

    # 构建结果数组
    local result="["
    local has_items=false

    # 1. 获取Codex Free
    local codex_free=$(_code88_get_codex_free "$token" "$tenant_id")

    if [[ -n "$codex_free" ]] && [[ "$codex_free" != "null" ]]; then
        result="${result}${codex_free}"
        has_items=true
    fi

    # 2. 获取订阅（FREE和PAYGO）
    local subscriptions=$(_code88_get_subscriptions "$token" "$tenant_id")

    if [[ -n "$subscriptions" ]] && [[ "$subscriptions" != "[]" ]]; then
        # 提取数组中的每个元素
        local sub_count=$(echo "$subscriptions" | jq 'length')

        for ((i=0; i<sub_count; i++)); do
            local sub=$(echo "$subscriptions" | jq ".[$i]")

            if $has_items; then
                result="${result},"
            fi

            result="${result}${sub}"
            has_items=true
        done
    fi

    result="${result}]"

    # 返回结果
    if $has_items; then
        echo "$result"
    else
        echo '[]'
        return 1
    fi
}
