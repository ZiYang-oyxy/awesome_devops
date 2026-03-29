# tmux 脚本结构说明

## 目录职责
当前目录仅保留一层脚本，不再使用 `scripts/` 和 `tmux-status/` 子目录。

- `tmux_session.sh`: 会话入口（新建、重命名、移动、切换、编号维护）。
- `tmux_session_manager.py`: 会话排序与重命名核心逻辑。
- `tmux_layout.sh`: pane 布局构建与横竖切换。
- `tmux_statusd.sh`: `tmux-statusd` / `tmux-statusctl` 的轻量包装与启动入口。

## 调用链
```mermaid
flowchart TD
    A[".tmux.conf hooks / status cache"] --> B["tmux_statusd.sh emit/query/start"]
    A --> C["tmux-statusctl ack-focus / pane-closed / notify-done"]
    A --> D["tmux_session.sh"]
    A --> E["tmux_layout.sh"]
    D --> F["tmux_session_manager.py"]
    B --> G["tmux-statusctl / tmux-statusd"]
    C --> G
    G --> H["${XDG_CACHE_HOME:-$HOME/.cache}/tmux-statusd"]
```

## 图标口径
- `🧠`: 由 daemon 汇总 `pane_current_command` 为 `codex*` 的 pane 数量。
- `🔔`: 由 daemon 汇总 `completed && !acknowledged` 的任务数量。
- pane 级 `🔔`: 只判断当前 `pane_id` 是否存在未确认完成任务。

## 当前实现
- 主链路已经是 daemon-only：shell 层只保留 `emit/query/start` 和 `session/layout` 入口。
- `status-left`、window suffix、pane border 的最终字符串通过 tmux option cache 提供，redraw 热路径不再依赖旧 shell 状态机。
- `ack-focus`、`pane-closed`、`notify-done` 已收进 `tmux-statusctl`，不再经过 shell 桥接脚本。
- 旧状态文件、旧 shell 查询缓存、旧 fallback 查询逻辑都已移除。

## daemon 状态目录
- 默认路径：`${XDG_CACHE_HOME:-$HOME/.cache}/tmux-statusd`
- 可覆盖：`TMUX_STATUSD_STATE_DIR`
- 目录内容：`statusd.sock`、`state.json`、`health.json`、`events.jsonl`、`spool/`
