# tmux 脚本结构说明

## 目录职责
- `scripts/`: pane/window/session 布局与交互脚本。
- `tmux-status/`: 状态栏与 pane-border 状态展示脚本。
- `tmux-status/status_engine.sh`: 状态计算与读写唯一入口。
- `tmux-status/lib_*.sh`: 状态锁、状态存储、查询与渲染公共函数。

## 状态流（v2）
```mermaid
flowchart TD
    A[Codex notify<br/>codex_notify_mark_done.sh] --> C[status_engine event complete]
    B[tmux focus hook<br/>ack_on_pane_focus.sh] --> D[status_engine event ack]
    C --> E[/tmp/tmux-status-state.v2.json]
    D --> E
    E --> F[status_engine query]
    F --> G[left.sh]
    F --> H[window_task_icon.sh]
    F --> I[pane_task_icon.sh]
    F --> J[codex_pane_suffix.sh]
```

## 图标口径（统一规则）
- `🤖`：按 `tmux list-panes -a` 中 `pane_current_command == "codex"` 计数。
- `🔔`：按状态文件中 `status=completed && acknowledged!=true` 计数。
- `pane` 级 `🔔`：只判断当前 `pane_id` 是否存在未确认完成任务。

## 入口脚本兼容策略
- `.tmux.conf` 仍引用原脚本名，不需要修改入口路径。
- 旧脚本仅作为轻量包装层，统一调用 `status_engine.sh`。
- 已移除未使用旧路径：
  - `tmux-status/session_task_icon.sh`
  - `tmux-status/tracker_cache.sh`
  - `tmux-status/codex_session_sync.sh`

## 状态文件
- 默认路径：`/tmp/tmux-status-state.v2.json`
- 可覆盖：`TMUX_STATUS_STATE_FILE`
- 兼容旧变量：`TMUX_TRACKER_CACHE_FILE`
