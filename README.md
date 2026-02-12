# ⚙Awesome Devops (or yet another AirDrop)⚙

## Mac/Linux一键安装

```bash
bash <(curl -s http://Awesome:Devops@ad-example.com:8890/@aadi@) && source ~/.bashrc
```

## 用途

ad是我工作以来持续积累的研发&运维工具和dotfile，做到尽量零依赖，一键安装，方便在任何环境上开箱即用，同时实现了方便的文件中转（需要搭配http server）。

> 工具介绍可能远落后于最新版本，ad tree可以看到所有工具的路径，大部分都是脚本，可自行摸索。有些开发工具可能会自动安装rpm，只适配了centos

## ad help

```
# ad

⚙ Awesome Devops (or yet another AirDrop) ⚙

Usage:  ad [ COMMAND | TOOL ] [ ARGUMENT ]
        ad deploy < PLUGIN >

    BASIC COMMAND:
        help      # this message
        upgrade   # upgrade to latest version
        uninstall # leave no trace
        tree      # prints out ad directory in a tree-like display
        [ put | tput | get ] <file>
        [ dput | dgput | dget ] <directory>

    TOOL:
        bg                    让命令后台运行
        bpftrace/             预置一些通用的bt脚本
        cecho                 colorful echo
        chat_stat
        ColorPalette          终端调色板
        cpi_ff/               CPI火焰图
        dpdk/                 dpdk工具箱
        eat_cpu               跑满指定CPU
        hostname_i
        irq/                  各种查看中断统计的工具
        login_free            ssh批量免密
        login_stat            机器登录分析，用于闲置机器判定
        lstopo                查看cpu和内存分布
        perf_c2c              发现cache伪共享问题
        perf-tools/           内核&进程trace工具箱
        sshpass               显示地填密码做ssh登录
        ssh_retry
        StartupGraph          linux boot流程可视化
        virtionet_stat        virtio-net设备统计可视化
        watch/                watch命令支持滚屏
        youdao                有道词典CLI版

    EXTERNAL TOOL:

    PLUGIN install:
        deploy bash
        deploy bpftrace
        deploy gdb
        deploy git
        deploy oyxy_dotfiles
        deploy prometheus
        deploy pssh
        deploy xfinder

Upload link:
http://Awesome:Devops@ad-example.com:8889

Install or Upgrade:
bash <(curl -s http://Awesome:Devops@ad-example.com:8890/@aadi@) && source ~/.bashrc

Home page:
ad-example.com
```

## 基础用法（有服务端）

```bash
# 安装
SERVER_IP=1.1.1.1; bash <(curl -s http://Awesome:Devops@$SERVER_IP:8890/@aadi@) && source ~/.bashrc

# 升级
ad upgrade

# 查看help（此时会有版本检查，有新版本会提示升级）
ad

# 上传文件
ad put <file>

# 下载文件
ad get <file>
```

## 基础用法（无服务端）

```bash
# 安装
./offline_install.sh

# 查看help
ad
```

## 开发态外部目录叠加

为了保持仓库干净，`upload.sh` 不再把外部工具同步回当前仓库。  
`ad` 会在运行时自动叠加外部目录：

- 默认外部目录：`../ad_external/awesome_devops`（相对于 `ad` 脚本所在目录）
- 可通过环境变量覆盖：`AD_EXTERNAL_DIR=/path/to/awesome_devops`
- 同名冲突优先级：内置目录优先，外部目录只补充缺失工具

示例：

```bash
AD_EXTERNAL_DIR=~/code/ad_external/awesome_devops ad help
```

## FAQ

Q: Mac的同学用safari浏览器无法访问链接

> A: 换个浏览器试试，推荐用Chrome

Q: Mac的终端上安装后报错

> A: ad大量使用bash脚本编写，不一定完全支持zsh环境，MacOS上从默认的zsh切到bash方法：chsh -s /bin/bash。同时由于作者的mac上使用的都是gnu版本的工具，所以不保证mac原生工具没有兼容性问题

## 常用功能说明

### 文件中转（通过命令行）

![](./docs/命令行上传下载.gif)

```bash
# 传文件
ad put <LOCAL_FILE_PATH> [REMOTE_FILE_NAME]
ad get <REMOTE_FILE_NAME> [LOCAL_FILE_PATH]

# 传文件夹（忽略了.git目录）
ad dput <LOCAL_DIR_PATH>
ad dget <REMOTE_DIR_NAME>
```

### 文件中转（通过浏览器）

![web上传下载.gif](./docs/web上传下载.gif)

### xfinder —— 高效查找、检索工具

包装了grep和find命令，能区分文件类型进行检索，选择匹配结果后可实现快速跳转，长久以来辅助我高效完成任何编程语言的代码流程分析
![xfinder.gif](./docs/xfinder.gif)

```bash
# 安装
ad deploy xfinder && source ~/.bashrc

# grep系列
xgrep #检索任意文件
cgrep #检索c/cpp等c语言文件
mgrep #检索make/cmake/meson等编译文件
cgrepi #结尾加i匹配不区分大小写
_cgrep #直接打印结果，不提供交互界面，一般配合xargs用

# find系列
xfind #任何包含指定字符串的文件和文件夹
xfindi #不区分大小写
_xfind #直接打印结果

# 更多用法特别是如果要使用正则表达式，参考源码 ~/.awesome_devops/plugins/xfinder/xfinder.source
```

### ssh多机并行执行

云上经常需要批量处理多台机器，例如批量升级，批量收集日志、版本等等，ad实现了ssh免密工具，同时集成了低版本的pssh（最新版对python高版本有依赖，不易部署）来支持批处理功能。
![pssh.gif](./docs/pssh.gif)

### GDB dashboard

本身是个开源工具，但是针对一些旧版本的linux发行版经常用起来有些问题，所以我做了适配并修改了我自己的常用配置
![gdb.gif](./docs/gdb.gif)

### CPI火焰图

CPI火焰图能很好地协助我进行程序的性能分析，同时也能快速了解整个程序的运行流程，ad把依赖的工具打包封装到了cpi_ff（同时适配了一些常见的cpu，无法正确显示的情况下，PMU的配置需要自行查阅手册并修改cpi_ff脚本）。用法如下：
![cpiff.svg](./docs/cpiff.svg)

```bash
# 抓线程的火焰图，对于dpdk这类R2C的线程比较适合
ad cpi_ff "-t <tid>" <output_filename>

# 抓进程的火焰图
ad cpi_ff "-p <pid>" <output_filename>
```

> 参考文章1 [https://www.brendangregg.com/perf.html](https://www.brendangregg.com/perf.html)
>
> 参考文章2 [https://developer.aliyun.com/article/465499](https://developer.aliyun.com/article/465499)
>
> Intel cpu PMU查询（XEON系列要注意找“Server Events”的表） [https://perfmon-events.intel.com/#](https://perfmon-events.intel.com/)

### 内核/进程trace

这类工具的好处是敏捷，使用场景广，不依赖源码重新编译的情况下，完成大量内核/进程逻辑问题和性能问题的分析

#### 初阶版（ad perf-tools）

**Trace进程**

```bash
ad perf-tools uprobe -H -s 'r:bash:readline +0($retval):string'
Tracing uprobe readline (r:readline /usr/bin/bash:0xd5690 +0($retval):string). Ctrl-C to end.
# tracer: nop
#
# entries-in-buffer/entries-written: 0/0   #P:1
#
#                                _-----=> irqs-off/BH-disabled
#                               / _----=> need-resched
#                              | / _---=> hardirq/softirq
#                              || / _--=> preempt-depth
#                              ||| / _-=> migrate-disable
#                              |||| /     delay
#           TASK-PID     CPU#  |||||  TIMESTAMP  FUNCTION
#              | |         |   |||||     |         |
            bash-649700  [000] ..... 7482270.891890: readline: (0x55b45485d015 <- 0x55b4548fd690) arg1="ls"
            bash-649700  [000] ..... 7482270.891918: <user stack trace>
 =>  <000055b45485d015>

# 如果需要查询代码行，使用addr2line，例如
addr2line -e /usr/bin/bash 000055b45485d015
```

**Trace内核**

```bash
# ad perf-tools funcgraph -a <function> 跟踪函数执行流程
ad perf-tools funcgraph -a do_nanosleep | head -20
Tracing "do_nanosleep"... Ctrl-C to end.
# tracer: function_graph
#
#     TIME        CPU  TASK/PID         DURATION                  FUNCTION CALLS
#      |          |     |    |           |   |                     |   |   |   |
7482405.739168 |   0)   xray-3952    |               |  do_nanosleep() {
7482405.739202 |   0)   xray-3952    |   1.200 us    |    irq_enter_rcu();
7482405.739203 |   0)   xray-3952    |               |    __sysvec_irq_work() {
7482405.739204 |   0)   xray-3952    |   0.600 us    |      hv_apic_eoi_write();
7482405.739205 |   0)   xray-3952    |               |      __wake_up() {
7482405.739205 |   0)   xray-3952    |               |        __wake_up_common_lock() {
7482405.739206 |   0)   xray-3952    |   0.300 us    |          _raw_spin_lock_irqsave();
7482405.739206 |   0)   xray-3952    |               |          __wake_up_common() {
7482405.739207 |   0)   xray-3952    |               |            autoremove_wake_function() {
7482405.739207 |   0)   xray-3952    |               |              default_wake_function() {
7482405.739208 |   0)   xray-3952    |               |                try_to_wake_up() {
7482405.739208 |   0)   xray-3952    |   0.700 us    |                  _raw_spin_lock_irqsave();
7482405.739209 |   0)   xray-3952    |   0.300 us    |                  ttwu_queue_wakelist();
7482405.739210 |   0)   xray-3952    |               |                  raw_spin_rq_lock_nested() {
7482405.739210 |   0)   xray-3952    |   0.400 us    |                    _raw_spin_lock();

# ad perf-tools functrace -H <function_regexp> 跟踪函数backtrace
ad perf-tools functrace -H '*sleep' | head -20
Tracing "*sleep"... Ctrl-C to end.
# tracer: function
#
# entries-in-buffer/entries-written: 0/0   #P:1
#
#                                _-----=> irqs-off/BH-disabled
#                               / _----=> need-resched
#                              | / _---=> hardirq/softirq
#                              || / _--=> preempt-depth
#                              ||| / _-=> migrate-disable
#                              |||| /     delay
#           TASK-PID     CPU#  |||||  TIMESTAMP  FUNCTION
#              | |         |   |||||     |         |
      multipathd-110947  [000] ..... 7482544.968639: __x64_sys_clock_nanosleep <-do_syscall_64
      multipathd-110947  [000] ..... 7482544.968674: common_nsleep <-__x64_sys_clock_nanosleep
      multipathd-110947  [000] ..... 7482544.968674: hrtimer_nanosleep <-common_nsleep
      multipathd-110947  [000] ..... 7482544.968675: do_nanosleep <-hrtimer_nanosleep
      containerd-110415  [000] ..... 7482545.395097: __x64_sys_nanosleep <-do_syscall_64
      containerd-110415  [000] ..... 7482545.395134: hrtimer_nanosleep <-__x64_sys_nanosleep
      containerd-110415  [000] ..... 7482545.395134: do_nanosleep <-hrtimer_nanosleep
```

#### 进阶版（bpftrace）

ad集成了在x86上可直接运行的零依赖的最新版本bpftrace，linux发行版配套的版本一般都太老。bpftrace的使用，可以执行`ad bpftrace usage`阅读使用指南
> bpftrace的一些新feature可以参考 [https://github.com/iovisor/bpftrace/blob/master/CHANGELOG.md](https://github.com/iovisor/bpftrace/blob/master/CHANGELOG.md)

### virtio-net stats

一直没有找到一个很好用的virtio-net性能观测工具，所以按照自己的想法，把网卡统计、中断统计、中断配置、rps/xps配置打散之后，重新基于virtio queue组合呈现
![virtionet_stats.gif](./docs/virtionet_stats.gif)
