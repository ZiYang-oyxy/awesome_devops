#!/bin/bash
# main.sh - tmux statusline调用入口（自动更新缓存）

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载所有库
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/cache.sh"
source "${SCRIPT_DIR}/lib/calculator.sh"
source "${SCRIPT_DIR}/lib/core.sh"

# 缓存有效期（秒）
CACHE_TTL=30

# 检查缓存是否有效
is_cache_valid() {
	local cache_file="${SCRIPT_DIR}/.cache/current.json"

	# 缓存文件不存在
	if [[ ! -f "$cache_file" ]]; then
		return 1
	fi

	# 获取缓存文件的修改时间
	local cache_mtime=$(get_mtime "$cache_file")
	if [[ -z "$cache_mtime" ]]; then
		return 1
	fi

	# 获取当前时间
	local current_time=$(get_timestamp)

	# 计算时间差
	local age=$((current_time - cache_mtime))

	# 检查是否在有效期内
	if [[ $age -lt $CACHE_TTL ]]; then
		return 0
	else
		return 1
	fi
}

# 更新缓存
update_cache() {
	# 静默执行，只在出错时输出
	{
		# 检查依赖
		if ! check_dependencies; then
			return 1
		fi

		# 加载环境变量
		if ! load_env; then
			return 1
		fi

		# 加载供应商插件
		if ! load_providers; then
			return 1
		fi

		# 初始化缓存
		if ! init_cache; then
			return 1
		fi

		# 检查是否需要0点重置
		check_midnight_reset

		# 更新所有启用的供应商
		update_all_providers
	} >/dev/null 2>&1

	return 0
}

# 检查后台更新是否在运行
is_update_running() {
	local lock_file="$(get_cache_dir)/update.lock"

	if [[ ! -f "$lock_file" ]]; then
		return 1
	fi

	local pid=""
	pid=$(cat "$lock_file" 2>/dev/null)
	if [[ -z "$pid" ]]; then
		rm -f "$lock_file"
		return 1
	fi

	if kill -0 "$pid" 2>/dev/null; then
		return 0
	fi

	rm -f "$lock_file"
	return 1
}

# 异步更新缓存（避免阻塞tmux状态栏）
update_cache_async() {
	local cache_dir="$(get_cache_dir)"
	local lock_file="${cache_dir}/update.lock"

	ensure_dir "$cache_dir" || return 1

	if is_update_running; then
		return 0
	fi

	(
		# 竞争锁，避免多进程重复更新
		if (
			set -o noclobber
			echo "$BASHPID" >"$lock_file"
		) 2>/dev/null; then
			sleep 5
			update_cache
			rm -f "$lock_file"
		fi
	) &

	return 0
}

# 判断是否隐藏某个订阅（仅影响显示，不影响数据处理）
should_hide_subscription() {
	local provider_name="$1"
	local sub_id="$2"

	# 默认隐藏88Code的FREE订阅，可通过环境变量重新开启
	if [[ "$provider_name" == "code88" ]] && [[ "$sub_id" == "free" ]]; then
		if [[ "$CODE88_SHOW_FREE" == "true" ]] || [[ "$CODE88_SHOW_FREE" == "1" ]]; then
			return 1
		fi
		if [[ "$CODE88_HIDE_FREE" == "false" ]] || [[ "$CODE88_HIDE_FREE" == "0" ]]; then
			return 1
		fi
		return 0
	fi

	return 1
}

# 格式化输出
format_output() {
	local cache_file="${SCRIPT_DIR}/.cache/current.json"
	local env_file="${SCRIPT_DIR}/.env"

	# 检查缓存文件是否存在
	if [[ ! -f "$cache_file" ]]; then
		echo "N/A"
		return 0
	fi

	# 读取缓存
	local cache_json=$(cat "$cache_file" 2>/dev/null)

	if [[ -z "$cache_json" ]]; then
		echo "N/A"
		return 0
	fi

	# 获取providers数组
	local providers=$(echo "$cache_json" | jq -r '.providers // []')

	# 过滤未启用的供应商（当.env存在时）
	local enabled_lookup=""
	if [[ -f "$env_file" ]]; then
		local enabled_providers=($(get_enabled_providers))
		enabled_lookup=" ${enabled_providers[*]} "
	fi

	# 构建输出字符串
	local output=""
	local provider_count=$(echo "$providers" | jq 'length')

	for ((i = 0; i < provider_count; i++)); do
		local provider=$(echo "$providers" | jq ".[$i]")

		local display=$(echo "$provider" | jq -r '.display')
		local provider_name=$(echo "$provider" | jq -r '.name')

		if [[ -f "$env_file" ]] && [[ "$enabled_lookup" != *" ${provider_name} "* ]]; then
			continue
		fi
		local has_error=$(echo "$provider" | jq -r '.error // false')
		local subscriptions=$(echo "$provider" | jq -r '.subscriptions')

		local sub_count=$(echo "$subscriptions" | jq 'length')

		# 开始provider组
		local provider_output="["

		# 如果有错误，添加红色"!"标记
		if [[ "$has_error" == "true" ]]; then
			provider_output="${provider_output}#[fg=colour199,bold]!#[default]"
		fi

		# 添加provider简称
		provider_output="${provider_output}${display}:"

		local visible_count=0

		for ((j = 0; j < sub_count; j++)); do
			local sub=$(echo "$subscriptions" | jq ".[$j]")

			local sub_id=$(echo "$sub" | jq -r '.id // ""')
			local sub_display=$(echo "$sub" | jq -r '.display // ""')
			local daily_usage=$(echo "$sub" | jq -r '.daily_usage // 0')
			local remaining=$(echo "$sub" | jq -r '.remaining // 0')

			if should_hide_subscription "$provider_name" "$sub_id"; then
				continue
			fi

			# 如果不是第一个subscription，添加分隔符
			if [[ $visible_count -gt 0 ]]; then
				provider_output="${provider_output}|"
			fi

			# 添加套餐名（如果有）
			if [[ -n "$sub_display" ]]; then
				provider_output="${provider_output}${sub_display}"
			fi

			# 添加余额
			provider_output="${provider_output}${remaining}"

			# 如果有消耗，添加带颜色的消耗显示
			if (($(echo "$daily_usage > 0" | bc -l))); then
				provider_output="${provider_output}#[fg=colour226 bold]↓${daily_usage}#[default]"
			fi

			((visible_count++))
		done

		# 结束provider组
		provider_output="${provider_output}]"

		if [[ $visible_count -gt 0 || "$has_error" == "true" ]]; then
			# 添加到总输出
			if [[ -n "$output" ]]; then
				output="${output} "
			fi
			output="${output}${provider_output}"
		fi
	done

	# 输出结果
	if [[ -n "$output" ]]; then
		echo "$output"
	else
		echo "N/A"
	fi
}

# 主函数
main() {
	# 尝试加载.env以获取显示开关（不影响更新逻辑）
	if [[ -f "${SCRIPT_DIR}/.env" ]]; then
		load_env >/dev/null 2>&1
	fi

	# 先读取并输出旧缓存，再触发后台更新，避免状态栏闪烁
	local output
	output="$(format_output)"

	# 检查缓存是否有效
	if ! is_cache_valid; then
		# 缓存无效或不存在，后台更新（等待下一次刷新显示新结果）
		update_cache_async
	fi

	echo "$output"
}

# 执行主函数
main "$@"
