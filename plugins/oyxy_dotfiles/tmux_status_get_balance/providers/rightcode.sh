#!/bin/bash
# rightcode.sh - RightCode供应商插件

# 返回供应商显示名称
provider_rightcode_display_name() {
	echo "R"
}

# 获取RightCode余额
provider_rightcode_fetch() {
	local token="$1"

	local api_url="https://www.right.codes/account/summary"

	# 调用API，同时获取HTTP状态码
	local temp_file=$(mktemp)
	local http_code=$(curl -s -w "%{http_code}" -o "$temp_file" \
		--location \
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

	# 优先使用subscriptions，balance作为paygo余额补充
	local subscriptions=$(echo "$response" | jq -c '.subscriptions // [] | map({
      id: (.id | tostring),
      name: (.name // ""),
      display: (if ((.name // "") | test("paygo"; "i")) then "P" elif ((.name // "") | test("阅")) then "S" else "" end),
      total: (.total_quota // 0),
      remaining: (.remaining_quota // 0)
    })')

	local balance=$(echo "$response" | jq -r '.balance // 0')

	local has_paygo=$(echo "$subscriptions" | jq -r 'map(select(.display == "P")) | length')
	if [[ "$has_paygo" == "0" ]]; then
		subscriptions=$(echo "$subscriptions" | jq -c ". + [{\"id\":\"paygo\",\"name\":\"Paygo\",\"display\":\"P\",\"total\":$balance,\"remaining\":$balance}]")
	fi

	if [[ -n "$subscriptions" ]] && [[ "$subscriptions" != "[]" ]]; then
		echo "$subscriptions"
		return 0
	fi

	cat <<EOF
[
  {
    "id": "paygo",
    "name": "Paygo",
    "display": "P",
    "total": $balance,
    "remaining": $balance
  }
]
EOF
}
