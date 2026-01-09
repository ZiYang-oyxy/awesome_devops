#!/bin/bash
# calculator.sh - 今日消耗计算逻辑

# 检查是否需要执行0点重置
check_midnight_reset() {
    local current_date="$(get_date)"
    local baseline_date="$(get_baseline_date)"
    local baseline_metric="$(get_baseline_metric)"
    local desired_metric="$(get_usage_metric)"
    local need_reset=0

    # 如果日期不同，说明跨0点了
    if [[ "$baseline_date" != "$current_date" ]]; then
        log "检测到日期变化: $baseline_date -> $current_date，执行0点重置" "INFO"
        need_reset=1
    fi

    if [[ "$baseline_metric" != "$desired_metric" ]]; then
        log "检测到基准指标变化: ${baseline_metric:-none} -> $desired_metric，执行基准重置" "INFO"
        need_reset=1
    fi

    if [[ $need_reset -eq 1 ]]; then
        reset_daily_baseline "$current_date"
        return 0
    fi

    return 1
}

# 重置每日基准
reset_daily_baseline() {
    local new_date="$1"

    reset_all_baselines "$new_date"
}

# daily_usage使用的指标（remaining/total）
get_usage_metric() {
    echo "remaining"
}

# 获取用于计算的值（默认remaining，缺失时回退total）
get_usage_value() {
    local provider="$1"
    local subscription="$2"
    local total="$3"
    local remaining="$4"

    local metric="$(get_usage_metric)"

    if [[ "$metric" == "remaining" ]]; then
        if [[ -n "$remaining" ]] && [[ "$remaining" != "null" ]]; then
            echo "$remaining"
        else
            echo "$total"
        fi
        return 0
    fi

    echo "$total"
}

# 从历史记录中提取用于计算的值
get_usage_value_from_record() {
    local provider="$1"
    local subscription="$2"
    local record_json="$3"

    local total=$(echo "$record_json" | jq -r '.total // empty')
    local remaining=$(echo "$record_json" | jq -r '.remaining // empty')

    get_usage_value "$provider" "$subscription" "$total" "$remaining"
}

# 计算今日消耗
calculate_daily_usage() {
    local provider="$1"
    local subscription="$2"
    local current_total="$3"
    local current_remaining="$4"
    local usage_mode="${5:-}"

    local key="${provider}.${subscription}"
    if [[ "$current_total" == "null" ]] || [[ -z "$current_total" ]]; then
        current_total="0"
    fi
    if [[ "$current_remaining" == "null" ]] || [[ -z "$current_remaining" ]]; then
        current_remaining="0"
    fi

    # 日额度类套餐：直接用 total - remaining 作为当天消耗
    if [[ "$usage_mode" == "daily_total" ]]; then
        local usage=$(echo "$current_total - $current_remaining" | bc)
        if compare_numbers "$usage" "<" "0"; then
            usage="0"
        fi
        format_number "$usage" 2
        return 0
    fi

    local current_value=$(get_usage_value "$provider" "$subscription" "$current_total" "$current_remaining")

    # 读取基准值
    local baseline_json="$(read_baseline "$key")"
    local value_at_start=$(echo "$baseline_json" | jq -r '.value_at_start // 0')
    local accumulated=$(echo "$baseline_json" | jq -r '.accumulated_usage // 0')

    # 如果基准值为0，说明是首次记录，设置基准值
    if [[ "$value_at_start" == "0" ]] || [[ "$value_at_start" == "0.00" ]]; then
        # 尝试使用0点基准记录（避免基准创建过晚）
        local current_date="$(get_date)"
        local start_record="$(get_record_for_day_start "$provider" "$subscription" "$current_date")"
        local day_start_value=""

        if [[ -n "$start_record" ]] && [[ "$start_record" != "{}" ]] && [[ "$start_record" != "null" ]]; then
            day_start_value=$(get_usage_value_from_record "$provider" "$subscription" "$start_record")
        fi

        if [[ -n "$day_start_value" ]] && [[ "$day_start_value" != "null" ]]; then
            update_baseline "$key" "$day_start_value" "0"
            local usage=$(echo "$day_start_value - $current_value" | bc)
            if compare_numbers "$usage" "<" "0"; then
                log "警告: ${key} 计算出的消耗为负数 ($usage)，重置为0" "WARN"
                usage="0"
            fi
            format_number "$usage" 2
            return 0
        fi

        update_baseline "$key" "$current_value" "0"
        echo "0.00"
        return 0
    fi

    # 今日消耗 = 基准值 - 当前值 + 已累计消耗
    # 这个公式确保充值不会影响今日消耗的计算
    local usage=$(echo "$value_at_start - $current_value + $accumulated" | bc)

    # 确保消耗不为负数
    if compare_numbers "$usage" "<" "0"; then
        log "警告: ${key} 计算出的消耗为负数 ($usage)，重置为0" "WARN"
        usage="0"
    fi

    format_number "$usage" 2
}

# 检测充值事件
detect_recharge() {
    local provider="$1"
    local subscription="$2"
    local current_total="$3"
    local current_remaining="$4"

    # 获取上一次的总额记录
    local last_record="$(get_last_record "$provider" "$subscription")"

    # 如果没有历史记录，不检测充值
    if [[ -z "$last_record" ]] || [[ "$last_record" == "{}" ]] || [[ "$last_record" == "null" ]]; then
        return 1
    fi

    local last_total=$(echo "$last_record" | jq -r '.total // 0')
    local last_remaining=$(echo "$last_record" | jq -r '.remaining // 0')
    local last_value=$(get_usage_value "$provider" "$subscription" "$last_total" "$last_remaining")
    local current_value=$(get_usage_value "$provider" "$subscription" "$current_total" "$current_remaining")

    # 如果当前值 > 上次值，检测到充值
    if compare_numbers "$current_value" ">" "$last_value"; then
        local recharge_amount=$(echo "$current_value - $last_value" | bc)
        log "充值检测: ${provider}.${subscription} +${recharge_amount} (${last_value} -> ${current_value})" "INFO"
        echo "$recharge_amount"
        return 0
    fi

    return 1
}

# 调整基准值（充值时调用）
adjust_baseline_for_recharge() {
    local provider="$1"
    local subscription="$2"
    local new_value="$3"
    local current_usage="$4"

    local key="${provider}.${subscription}"

    # 调整基准值：
    # 1. 新基准 = 当前总额
    # 2. 保留已累计的消耗
    update_baseline "$key" "$new_value" "$current_usage"

    log "调整基准值: ${key} value_at_start=${new_value}, accumulated_usage=${current_usage}" "INFO"
}

# 处理单个订阅的数据更新
process_subscription_update() {
    local provider="$1"
    local subscription="$2"
    local total="$3"
    local remaining="$4"
    local usage_mode="${5:-}"

    # 日额度类套餐不需要充值检测，直接按 total-remaining 计算
    if [[ "$usage_mode" == "daily_total" ]]; then
        local daily_usage=$(calculate_daily_usage "$provider" "$subscription" "$total" "$remaining" "$usage_mode")
        append_history "$provider" "$subscription" "$total" "$remaining"
        echo "$daily_usage"
        return 0
    fi

    # 1. 检测充值
    local recharge_amount=""
    local event=""

    if recharge_amount=$(detect_recharge "$provider" "$subscription" "$total" "$remaining"); then
        event="recharge_detected"

        # 获取当前消耗（充值前）
        local last_record="$(get_last_record "$provider" "$subscription")"
        local last_total=$(echo "$last_record" | jq -r '.total // 0')
        local last_remaining=$(echo "$last_record" | jq -r '.remaining // 0')
        local current_usage=$(calculate_daily_usage "$provider" "$subscription" "$last_total" "$last_remaining" "$usage_mode")
        local current_value=$(get_usage_value "$provider" "$subscription" "$total" "$remaining")

        # 调整基准值
        adjust_baseline_for_recharge "$provider" "$subscription" "$current_value" "$current_usage"
    fi

    # 2. 计算今日消耗
    local daily_usage=$(calculate_daily_usage "$provider" "$subscription" "$total" "$remaining" "$usage_mode")

    # 3. 追加历史记录
    if [[ -n "$event" ]]; then
        local extra_data="{\"recharge_amount\": $(format_number "$recharge_amount" 2)}"
        append_history "$provider" "$subscription" "$total" "$remaining" "$event" "$extra_data"
    else
        append_history "$provider" "$subscription" "$total" "$remaining"
    fi

    # 4. 返回包含daily_usage的数据
    echo "$daily_usage"
}

# 构建订阅的完整数据（包含daily_usage）
build_subscription_data() {
    local subscription_id="$1"
    local subscription_name="$2"
    local display="$3"
    local total="$4"
    local remaining="$5"
    local daily_usage="$6"

    cat <<EOF
{
  "id": "$subscription_id",
  "name": "$subscription_name",
  "display": "$display",
  "total": $(format_number "$total" 2),
  "remaining": $(format_number "$remaining" 2),
  "daily_usage": $(format_number "$daily_usage" 2)
}
EOF
}

# 批量处理provider的所有订阅
process_provider_subscriptions() {
    local provider="$1"
    local raw_subscriptions_json="$2"  # 来自provider_fetch的原始数据

    # 解析订阅数组
    local subscription_count=$(echo "$raw_subscriptions_json" | jq 'length')

    local processed_subscriptions="["
    local first=true

    for ((i=0; i<subscription_count; i++)); do
        local sub=$(echo "$raw_subscriptions_json" | jq ".[$i]")

        local sub_id=$(echo "$sub" | jq -r '.id')
        local sub_name=$(echo "$sub" | jq -r '.name')
        local sub_display=$(echo "$sub" | jq -r '.display // ""')
        local sub_total=$(echo "$sub" | jq -r '.total')
        local sub_remaining=$(echo "$sub" | jq -r '.remaining')
        local sub_usage_mode=$(echo "$sub" | jq -r '.usage_mode // ""')

        # 处理订阅更新（充值检测、消耗计算、历史记录）
        local daily_usage=$(process_subscription_update "$provider" "$sub_id" "$sub_total" "$sub_remaining" "$sub_usage_mode")

        # 构建订阅数据
        local sub_data=$(build_subscription_data "$sub_id" "$sub_name" "$sub_display" "$sub_total" "$sub_remaining" "$daily_usage")

        if $first; then
            processed_subscriptions="${processed_subscriptions}${sub_data}"
            first=false
        else
            processed_subscriptions="${processed_subscriptions},${sub_data}"
        fi
    done

    processed_subscriptions="${processed_subscriptions}]"

    echo "$processed_subscriptions"
}
