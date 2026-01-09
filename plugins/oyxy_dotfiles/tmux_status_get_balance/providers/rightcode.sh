#!/bin/bash
# rightcode.sh - RightCode供应商插件

# 返回供应商显示名称
provider_rightcode_display_name() {
    echo "R"
}

# 获取RightCode余额
provider_rightcode_fetch() {
    local token="$1"

    local api_url="https://www.right.codes/auth/me"

    # 调用API，同时获取HTTP状态码
    local temp_file=$(mktemp)
    local http_code=$(curl -s -w "%{http_code}" -o "$temp_file" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        "$api_url")
    local curl_exit=$?
    local response=$(cat "$temp_file")
    rm -f "$temp_file"

    # 检查curl是否执行成功
    if [[ $curl_exit -ne 0 ]]; then
        log "错误: RightCode curl请求失败，退出码: $curl_exit" "ERROR"
        echo '[]'
        return 2
    fi

    # 检查HTTP状态码
    if [[ "$http_code" != "200" ]]; then
        log "错误: RightCode API返回HTTP状态码: $http_code" "ERROR"
        echo '[]'
        return 3
    fi

    # 检查响应
    if [[ -z "$response" ]]; then
        log "错误: RightCode API返回空响应" "ERROR"
        echo '[]'
        return 1
    fi

    # 提取balance字段
    local balance=$(echo "$response" | jq -r '.balance // 0')

    # 构建标准格式的JSON数组
    cat <<EOF
[
  {
    "id": "main",
    "name": "Main Account",
    "display": "",
    "total": $balance,
    "remaining": $balance
  }
]
EOF
}
