#!/bin/bash
# cache.sh - 缓存管理库

# 获取缓存目录
get_cache_dir() {
    local script_dir="$(get_script_dir)"
    echo "${script_dir}/.cache"
}

# 获取current.json路径
get_current_cache_file() {
    echo "$(get_cache_dir)/current.json"
}

# 获取history.json路径
get_history_file() {
    echo "$(get_cache_dir)/history.json"
}

# 获取daily_baseline.json路径
get_baseline_file() {
    echo "$(get_cache_dir)/daily_baseline.json"
}

# 获取daily_usage基准指标（默认remaining）
get_usage_metric_safe() {
    if declare -f get_usage_metric >/dev/null 2>&1; then
        get_usage_metric
    else
        echo "remaining"
    fi
}

# 获取baseline的指标
get_baseline_metric() {
    local baseline_json="$(read_baseline_file)"
    echo "$baseline_json" | jq -r '.metric // ""'
}

# 获取指定日期的第一条记录
get_first_record_for_date() {
    local provider="$1"
    local subscription="$2"
    local date="$3" # YYYY-MM-DD

    local history_json="$(read_history)"

    echo "$history_json" | jq -c --arg provider "$provider" --arg subscription "$subscription" --arg date "$date" \
        '[.records[] | select(.provider == $provider and .subscription == $subscription and (.datetime | startswith($date)))] | min_by(.timestamp) // {}'
}

# 获取用于当天0点的基准记录（优先取0点前最后一条）
get_record_for_day_start() {
    local provider="$1"
    local subscription="$2"
    local date="$3" # YYYY-MM-DD

    local day_start_ts
    day_start_ts="$(get_day_start_timestamp "$date")"

    if [[ -z "$day_start_ts" ]] || [[ "$day_start_ts" == "0" ]]; then
        get_first_record_for_date "$provider" "$subscription" "$date"
        return 0
    fi

    local history_json="$(read_history)"

    local before_record=$(echo "$history_json" | jq -c --arg provider "$provider" --arg subscription "$subscription" --argjson ts "$day_start_ts" \
        '[.records[] | select(.provider == $provider and .subscription == $subscription and (.timestamp | tonumber) < $ts)] | max_by(.timestamp) // {}')

    if [[ -n "$before_record" ]] && [[ "$before_record" != "null" ]] && [[ "$before_record" != "{}" ]]; then
        echo "$before_record"
        return 0
    fi

    local after_record=$(echo "$history_json" | jq -c --arg provider "$provider" --arg subscription "$subscription" --argjson ts "$day_start_ts" \
        '[.records[] | select(.provider == $provider and .subscription == $subscription and (.timestamp | tonumber) >= $ts)] | min_by(.timestamp) // {}')

    echo "$after_record"
}

# 初始化缓存目录
init_cache() {
    local cache_dir="$(get_cache_dir)"

    ensure_dir "$cache_dir" || return 1

    # 初始化current.json
    local current_file="$(get_current_cache_file)"
    if [[ ! -f "$current_file" ]]; then
        cat > "$current_file" <<'EOF'
{
  "timestamp": 0,
  "last_update": "",
  "providers": []
}
EOF
    fi

    # 初始化history.json
    local history_file="$(get_history_file)"
    if [[ ! -f "$history_file" ]]; then
        cat > "$history_file" <<'EOF'
{
  "records": []
}
EOF
    fi

    # 初始化daily_baseline.json
    local baseline_file="$(get_baseline_file)"
    if [[ ! -f "$baseline_file" ]]; then
        local current_date="$(get_date)"
        local metric="$(get_usage_metric_safe)"
        cat > "$baseline_file" <<EOF
{
  "date": "$current_date",
  "metric": "$metric",
  "baselines": {}
}
EOF
    fi

    return 0
}

# 读取current.json
read_cache() {
    local current_file="$(get_current_cache_file)"

    if [[ ! -f "$current_file" ]]; then
        echo '{"timestamp": 0, "last_update": "", "providers": []}'
        return 1
    fi

    cat "$current_file"
}

# 获取指定provider的缓存对象
get_cached_provider() {
    local provider_name="$1"
    local cache_json="$(read_cache)"

    echo "$cache_json" | jq -c --arg provider "$provider_name" \
        '(.providers // []) | map(select(.name == $provider)) | .[0] // {}'
}

# 写入current.json
write_cache() {
    local content="$1"
    local current_file="$(get_current_cache_file)"

    atomic_write "$content" "$current_file"
}

# 读取history.json
read_history() {
    local history_file="$(get_history_file)"

    if [[ ! -f "$history_file" ]]; then
        echo '{"records": []}'
        return 1
    fi

    cat "$history_file"
}

# 追加历史记录
append_history() {
    local provider="$1"
    local subscription="$2"
    local total="$3"
    local remaining="$4"
    local event="${5:-}"
    local extra_data="${6:-}"

    local history_file="$(get_history_file)"
    local timestamp="$(get_timestamp)"
    local datetime="$(get_datetime)"

    # 读取现有历史
    local history_json="$(read_history)"

    # 构建新记录
    local new_record=$(cat <<EOF
{
  "timestamp": $timestamp,
  "datetime": "$datetime",
  "provider": "$provider",
  "subscription": "$subscription",
  "total": $total,
  "remaining": $remaining
EOF
)

    # 添加可选字段
    if [[ -n "$event" ]]; then
        new_record="$new_record,
  \"event\": \"$event\""
    fi

    if [[ -n "$extra_data" ]]; then
        new_record="$new_record,
  \"extra_data\": $extra_data"
    fi

    new_record="$new_record
}"

    # 追加到records数组
    local updated_history=$(echo "$history_json" | jq ".records += [$new_record]")

    # 写入文件
    atomic_write "$updated_history" "$history_file"
}

# 获取最后一条记录
get_last_record() {
    local provider="$1"
    local subscription="$2"

    local history_json="$(read_history)"

    # 筛选并获取最后一条记录
    echo "$history_json" | jq -r --arg provider "$provider" --arg subscription "$subscription" \
        '.records[] | select(.provider == $provider and .subscription == $subscription) | .' | jq -s '.[-1] // {}'
}

# 清理旧历史记录（保留最近N天）
clean_old_history() {
    local days="${1:-7}"
    local history_file="$(get_history_file)"

    local cutoff_timestamp=$(($(get_timestamp) - days * 86400))

    local history_json="$(read_history)"
    local cleaned_history=$(echo "$history_json" | jq --arg cutoff "$cutoff_timestamp" \
        '.records |= map(select(.timestamp >= ($cutoff | tonumber)))')

    atomic_write "$cleaned_history" "$history_file"

    local removed_count=$(echo "$history_json" | jq '.records | length')
    local remaining_count=$(echo "$cleaned_history" | jq '.records | length')
    local deleted=$((removed_count - remaining_count))

    log "清理历史记录: 删除 $deleted 条，保留 $remaining_count 条" "INFO"
}

# 读取baseline.json
read_baseline_file() {
    local baseline_file="$(get_baseline_file)"

    if [[ ! -f "$baseline_file" ]]; then
        local current_date="$(get_date)"
        local metric="$(get_usage_metric_safe)"
        echo "{\"date\": \"$current_date\", \"metric\": \"$metric\", \"baselines\": {}}"
        return 1
    fi

    cat "$baseline_file"
}

# 读取特定订阅的baseline
read_baseline() {
    local key="$1"  # provider.subscription格式

    local baseline_json="$(read_baseline_file)"

    echo "$baseline_json" | jq -r --arg key "$key" \
        '.baselines[$key] // {"value_at_start": 0, "accumulated_usage": 0}'
}

# 更新baseline
update_baseline() {
    local key="$1"  # provider.subscription格式
    local value_at_start="$2"
    local accumulated_usage="$3"

    local baseline_file="$(get_baseline_file)"
    local baseline_json="$(read_baseline_file)"

    # 更新或添加baseline
    local updated_json=$(echo "$baseline_json" | jq --arg key "$key" \
        --arg value "$value_at_start" \
        --arg accumulated "$accumulated_usage" \
        '.baselines[$key] = {
            "value_at_start": ($value | tonumber),
            "accumulated_usage": ($accumulated | tonumber)
        }')

    atomic_write "$updated_json" "$baseline_file"
}

# 重置所有baseline（0点调用）
reset_all_baselines() {
    local new_date="$1"
    local baseline_file="$(get_baseline_file)"
    local metric="$(get_usage_metric_safe)"

    # 保留date字段，清空baselines
    local reset_json=$(cat <<EOF
{
  "date": "$new_date",
  "metric": "$metric",
  "baselines": {}
}
EOF
)

    atomic_write "$reset_json" "$baseline_file"

    log "重置每日基准: $new_date" "INFO"
}

# 获取baseline的日期
get_baseline_date() {
    local baseline_json="$(read_baseline_file)"
    echo "$baseline_json" | jq -r '.date // ""'
}

# 构建provider的缓存数据
build_provider_cache() {
    local provider_name="$1"
    local display_name="$2"
    local subscriptions_json="$3"  # JSON数组
    local has_error="${4:-false}"  # 是否有错误

    cat <<EOF
{
  "name": "$provider_name",
  "display": "$display_name",
  "error": $has_error,
  "subscriptions": $subscriptions_json
}
EOF
}

# 更新current.json中的某个provider
update_provider_in_cache() {
    local provider_name="$1"
    local provider_data="$2"  # JSON对象

    local current_file="$(get_current_cache_file)"
    local cache_json="$(read_cache)"

    # 更新timestamp和last_update
    local timestamp="$(get_timestamp)"
    local datetime="$(get_datetime)"

    # 删除旧的provider数据，添加新的
    local updated_json=$(echo "$cache_json" | jq --arg provider "$provider_name" \
        --argjson provider_data "$provider_data" \
        --arg timestamp "$timestamp" \
        --arg datetime "$datetime" \
        '.timestamp = ($timestamp | tonumber) |
         .last_update = $datetime |
         .providers |= (map(select(.name != $provider)) + [$provider_data])')

    write_cache "$updated_json"
}
