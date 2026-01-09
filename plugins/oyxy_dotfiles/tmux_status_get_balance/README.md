# tmux Balance Monitor - 使用指南

## 项目简介

这是一个统一的API余额查询框架，用于在tmux状态栏显示多个服务供应商的额度使用情况。

### 主要特性

- **插件化架构**: 支持灵活添加多个服务供应商
- **智能缓存**: 30秒内复用缓存，减少API开销
- **今日消耗计算**: 自动计算每日消耗，0点自动重置
- **充值检测**: 智能识别充值事件并调整基准值
- **多套餐支持**: 支持单一供应商多个套餐独立统计
- **历史记录**: JSON格式存储历史数据，便于追溯

### 显示格式

```bash
R:5.2|23.4 8-CF:3.5|20.0 8-F:0|21.7 8-P:10.5|166.7 X:2.5|135.5
# 格式说明: <供应商>-<套餐>:<今日消耗>|<总额度>
# R = RightCode
# 8-CF = 88Code Codex Free
# 8-F = 88Code FREE Plan
# 8-P = 88Code PAYGO Plan
# X = XiaoHu
```

## 目录结构

```
tmux_status_get_balance/
├── .env                    # 配置文件（请勿提交到git）
├── .env.example            # 配置模板
├── .gitignore              # git忽略规则
├── .cache/                 # 数据缓存目录
│   ├── current.json        # 当前状态（供tmux读取）
│   ├── history.json        # 历史记录
│   └── daily_baseline.json # 每日基准值
├── main.sh                 # 主入口（tmux调用）
├── lib/                    # 核心库
│   ├── utils.sh            # 工具函数
│   ├── cache.sh            # 缓存管理
│   ├── calculator.sh       # 今日消耗计算
│   └── core.sh             # 核心逻辑
└── providers/              # 供应商插件
    ├── rightcode.sh        # RightCode
    ├── code88.sh           # 88Code
    └── xiaohu.sh           # XiaoHu
```

## 快速开始

### 1. 配置token

```bash
# 复制配置模板
cp .env.example .env

# 编辑配置文件，填写各个供应商的token
vim .env
```

配置示例：

```bash
# RightCode
RIGHTCODE_ENABLED=true
RIGHTCODE_TOKEN=your_token_here

# 88Code (注意：使用CODE88前缀，因为环境变量不能以数字开头)
CODE88_ENABLED=true
CODE88_TOKEN=your_token_here
CODE88_TENANT_ID=1

# XiaoHu
XIAOHU_ENABLED=true
XIAOHU_TOKEN=your_token_here
XIAOHU_USER_ID=your_user_id_here
```

### 2. 运行一次验证

```bash
# 测试一次更新（验证配置）
./main.sh
```

### 3. 配置tmux

在 `~/.tmux.conf` 中添加：

```bash
# 方式1: 仅显示余额
set -g status-right "#(/path/to/tmux_status_get_balance/main.sh) | %H:%M"

# 方式2: 与其他信息组合
set -g status-right "#(/path/to/tmux_status_get_balance/main.sh) | %Y-%m-%d %H:%M"
```

重新加载tmux配置：

```bash
tmux source-file ~/.tmux.conf
```

## 添加新供应商

### Step 1: 创建供应商插件

在 `providers/` 目录创建新文件，例如 `providers/newprovider.sh`：

```bash
#!/bin/bash
# newprovider.sh - 新供应商插件

# 返回供应商显示名称（1-2个字符）
provider_newprovider_display_name() {
    echo "N"
}

# 获取余额数据
provider_newprovider_fetch() {
    local token="$1"

    # 调用API
    local response=$(curl -s -H "Authorization: Bearer $token" \
        "https://api.example.com/balance")

    # 提取数据
    local balance=$(echo "$response" | jq -r '.balance // 0')

    # 返回标准格式的JSON数组
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
```

### Step 2: 添加配置

在 `.env` 文件中添加：

```bash
# New Provider
NEWPROVIDER_ENABLED=true
NEWPROVIDER_TOKEN=your_token_here
```

### Step 3: 注册供应商

编辑 `lib/core.sh`，在 `get_enabled_providers()` 函数中添加：

```bash
local known_providers=("rightcode" "code88" "xiaohu" "newprovider")
```

### Step 4: 重新运行

```bash
./main.sh
```

## 核心概念

### 今日消耗计算

```
今日消耗 = 基准总额 - 当前总额 + 已累计消耗
```

- **基准总额**: 0点后第一次查询时的总额度
- **当前总额**: 最新查询的总额度
- **已累计消耗**: 用于处理充值情况

#### 时区与0点

默认使用系统时区计算“当天0点”。如需按其它时区（例如供应商按北京时间重置），可在环境变量中设置：

```bash
USAGE_TZ=Asia/Shanghai
```

此时今日消耗会按该时区的0点进行计算。

### 充值检测

当检测到 `当前总额 > 上次总额` 时：

1. 记录充值事件到历史记录
2. 更新基准值为当前总额
3. 保留已累计的消耗（确保今日消耗不受影响）

### 0点重置

每天0点后第一次查询时：

1. 检测日期变化
2. 清空所有基准值
3. 重新设置新的基准值

## 文件说明

### 数据文件

#### .cache/current.json

当前状态，供tmux快速读取：

```json
{
  "timestamp": 1704355200,
  "last_update": "2024-01-04 10:30:00",
  "providers": [
    {
      "name": "rightcode",
      "display": "R",
      "subscriptions": [
        {
          "id": "main",
          "display": "",
          "total": 100.00,
          "remaining": 85.50,
          "daily_usage": 5.20
        }
      ]
    }
  ]
}
```

#### .cache/daily_baseline.json

每日基准值：

```json
{
  "date": "2024-01-04",
  "metric": "remaining",
  "baselines": {
    "rightcode.main": {
      "value_at_start": 90.70,
      "accumulated_usage": 5.20
    }
  }
}
```

#### .cache/history.json

历史记录（用于充值检测）：

```json
{
  "records": [
    {
      "timestamp": 1704355200,
      "datetime": "2024-01-04 10:30:00",
      "provider": "rightcode",
      "subscription": "main",
      "total": 100.00,
      "remaining": 85.50,
      "event": "recharge_detected",
      "extra_data": {
        "recharge_amount": 10.00
      }
    }
  ]
}
```

## 故障排查

### 问题1: main.sh无法运行或提示缺少依赖

```bash
# 检查依赖
which jq curl bc

# 如果缺少依赖，安装：
# macOS
brew install jq

# Linux
sudo apt-get install jq bc
```

### 问题2: tmux不显示数据

```bash
# 检查main.sh是否能执行
./main.sh

# 检查缓存文件是否存在
ls -la .cache/

# 手动执行一次更新
./main.sh
```

### 问题3: 今日消耗计算不准确

```bash
# 检查基准文件的日期
cat .cache/daily_baseline.json | jq '.date'

# 如果日期不对，手动删除基准文件重新初始化
rm .cache/daily_baseline.json
./main.sh
```

### 问题4: 88Code相关错误

注意：88Code在代码中使用 `CODE88` 作为环境变量前缀（因为bash不支持以数字开头的变量名）：

- 配置文件: `CODE88_ENABLED`, `CODE88_TOKEN`, `CODE88_TENANT_ID`
- 插件文件: `providers/code88.sh`
- 函数名: `provider_code88_*`

## 维护建议

### 定期清理历史记录

如需手动清理：

```bash
# 编辑.cache/history.json，删除旧记录
```

### 备份数据

重要数据都在 `.cache/` 目录：

```bash
# 备份
tar -czf cache_backup_$(date +%Y%m%d).tar.gz .cache/

# 恢复
tar -xzf cache_backup_YYYYMMDD.tar.gz
```

## 安全注意事项

1. **.env文件权限**: 已自动设置为600（仅所有者可读写）
2. **不要提交敏感信息**: .gitignore已配置忽略.env和.cache
3. **定期更新token**: 建议定期更换API token

## 性能优化

- **缓存有效期**: 默认30秒，可在main.sh中修改`CACHE_TTL`
- **tmux刷新频率**: main.sh为纯文件读取，可高频调用

## 致谢

本框架重构自以下原始脚本：
- `rightcode_balance.sh`
- `88code_balance.sh`
- `xiaohu_balance.sh`

备份文件已保存为 `*.bak`，供参考。
