#!/bin/bash
# xiaohu.sh - XiaoHu供应商插件

# 返回供应商显示名称
provider_xiaohu_display_name() {
    echo "X"
}

# 获取XiaoHu余额
provider_xiaohu_fetch() {
    local token="$1"

    # 获取user_id配置
    local user_id=$(get_provider_config "xiaohu" "USER_ID")

    if [[ -z "$user_id" ]]; then
        log "错误: XiaoHu USER_ID未配置" "ERROR"
        echo '[]'
        return 1
    fi

    local api_url="https://xiaohumini.site/api/user/self"

    # 调用API，同时获取HTTP状态码
    local temp_file=$(mktemp)
    local http_code=$(curl -s -w "%{http_code}" -o "$temp_file" -X GET "$api_url" \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer $token" \
        -H "New-Api-User: $user_id")
    local curl_exit=$?
    local response=$(cat "$temp_file")
    rm -f "$temp_file"

    # 检查curl是否执行成功
    if [[ $curl_exit -ne 0 ]]; then
        log "错误: XiaoHu curl请求失败，退出码: $curl_exit" "ERROR"
        echo '[]'
        return 2
    fi

    # 检查HTTP状态码
    if [[ "$http_code" != "200" ]]; then
        log "错误: XiaoHu API返回HTTP状态码: $http_code" "ERROR"
        echo '[]'
        return 3
    fi

    # 检查响应
    if [[ -z "$response" ]]; then
        log "错误: XiaoHu API返回空响应" "ERROR"
        echo '[]'
        return 1
    fi

    # 提取quota和used_quota
    local quota=$(echo "$response" | jq -r '.data.quota // 0')
    local used_quota=$(echo "$response" | jq -r '.data.used_quota // 0')

    # 转换为USD（500000单位 = 1 USD）
    local balance_usd=$(echo "scale=2; $quota / 500000" | bc)
    local used_usd=$(echo "scale=2; $used_quota / 500000" | bc)
    local total_usd=$(echo "scale=2; $balance_usd + $used_usd" | bc)

    # 构建标准格式的JSON数组
    cat <<EOF
[
  {
    "id": "main",
    "name": "Main Account",
    "display": "",
    "total": $total_usd,
    "remaining": $balance_usd
  }
]
EOF
}
