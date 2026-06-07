# 给perf添加自定义metric
## 1. 下载perfmon https://github.com/intel/perfmon.git

## 2. 添加自定义metrics

```diff
diff --git a/EMR/metrics/perf/emeraldrapids_metrics_perf.json b/EMR/metrics/perf/emeraldrapids_metrics_perf.json
index 04dc0e5..0b28892 100644
--- a/EMR/metrics/perf/emeraldrapids_metrics_perf.json
+++ b/EMR/metrics/perf/emeraldrapids_metrics_perf.json
@@ -193,6 +193,13 @@
         "MetricName": "upi_data_transmit_bw",
         "ScaleUnit": "1MB/s"
     },
+    {
+        "BriefDescription": "Intel(R) Ultra Path Interconnect (UPI) data receive bandwidth (MB/sec)",
+        "MetricExpr": "(UNC_UPI_RxL_FLITS.ALL_DATA * (64 / 9.0) / 1000000) / duration_time",
+        "MetricGroup": "",
+        "MetricName": "upi_data_receive_bw",
+        "ScaleUnit": "1MB/s"
+    },
     {
         "BriefDescription": "DDR memory read bandwidth (MB/sec)",
:...skipping...
diff --git a/EMR/metrics/perf/emeraldrapids_metrics_perf.json b/EMR/metrics/perf/emeraldrapids_metrics_perf.json
index 04dc0e5..0b28892 100644
--- a/EMR/metrics/perf/emeraldrapids_metrics_perf.json
+++ b/EMR/metrics/perf/emeraldrapids_metrics_perf.json
@@ -193,6 +193,13 @@
         "MetricName": "upi_data_transmit_bw",
         "ScaleUnit": "1MB/s"
     },
+    {
+        "BriefDescription": "Intel(R) Ultra Path Interconnect (UPI) data receive bandwidth (MB/sec)",
+        "MetricExpr": "(UNC_UPI_RxL_FLITS.ALL_DATA * (64 / 9.0) / 1000000) / duration_time",
+        "MetricGroup": "",
+        "MetricName": "upi_data_receive_bw",
+        "ScaleUnit": "1MB/s"
+    },
     {
         "BriefDescription": "DDR memory read bandwidth (MB/sec)",
         "MetricExpr": "(UNC_M_CAS_COUNT.RD * 64 / 1000000) / duration_time",
@@ -2200,6 +2207,13 @@
         "MetricGroup": "SoC;Server;MB/sec",
         "MetricName": "tma_info_system_upi_data_transmit_bw"
     },
+    {
+        "BriefDescription": "Cross-socket Ultra Path Interconnect (UPI) non-data transmit percent",
+        "MetricExpr": "UNC_UPI_TxL_FLITS.NON_DATA / UNC_UPI_CLOCKTICKS",
+        "MetricGroup": "",
+        "MetricName": "upi_tx_non_data_percent",
+        "ScaleUnit": "100%"
+    },
     {
         "BriefDescription": "Total package Power in Watts",
         "MetricExpr": "( power@energy\\-pkg@ * ( 61 ) + 15.6 * power@energy\\-ram@ ) / ( ( duration_time ) * ( 1000000 ) )",
@@ -2253,5 +2267,47 @@
         "MetricGroup": "HPC;Mem;MemoryBW;SoC;GB/sec",
         "MetricName": "tma_info_memory_soc_r2c_dram_bw",
         "PublicDescription": "Average DRAM BW for Reads-to-Core (R2C) covering for memory attached to local- and remote-socket. See R2C_Offcore_BW."
+    },
+    {
+        "BriefDescription": "Bandwidth observed by the integrated I/O traffic controller (IIO) of IO reads that are initiated by end device controllers that are requesting memory from the CPU",
+        "MetricExpr": "(UNC_IIO_DATA_REQ_OF_CPU.MEM_READ.ALL_PARTS * 4 / 1000000) / duration_time",
+        "MetricGroup": "",
+        "MetricName": "iio_bandwidth_read",
+        "ScaleUnit": "1MB/s"
+    },
+    {
+        "BriefDescription": "Bandwidth observed by the integrated I/O traffic controller (IIO) of IO writes that are initiated by end device controllers that are writing memory to the CPU",
+        "MetricExpr": "(UNC_IIO_DATA_REQ_OF_CPU.MEM_WRITE.ALL_PARTS * 4 / 1000000) / duration_time",
+        "MetricGroup": "",
+        "MetricName": "iio_bandwidth_write",
+        "ScaleUnit": "1MB/s"
+    },
+    {
+        "BriefDescription": "Bandwidth (MB/sec) of read requests that miss the last level cache (LLC) and go to local memory",
+        "MetricExpr": "(UNC_CHA_REQUESTS.READS_LOCAL * 64 / 1000000) / duration_time",
+        "MetricGroup": "",
+        "MetricName": "llc_miss_local_memory_bandwidth_read",
+        "ScaleUnit": "1MB/s"
+    },
+    {
+        "BriefDescription": "Bandwidth (MB/sec) of write requests that miss the last level cache (LLC) and go to local memory",
+        "MetricExpr": "(UNC_CHA_REQUESTS.WRITES_LOCAL * 64 / 1000000) / duration_time",
+        "MetricGroup": "",
+        "MetricName": "llc_miss_local_memory_bandwidth_write",
+        "ScaleUnit": "1MB/s"
+    },
+    {
+        "BriefDescription": "Bandwidth (MB/sec) of read requests that miss the last level cache (LLC) and go to remote memory",
+        "MetricExpr": "(UNC_CHA_REQUESTS.READS_REMOTE * 64 / 1000000) / duration_time",
+        "MetricGroup": "",
+        "MetricName": "llc_miss_remote_memory_bandwidth_read",
+        "ScaleUnit": "1MB/s"
+    },
+    {
+        "BriefDescription": "Bandwidth (MB/sec) of write requests that miss the last level cache (LLC) and go to remote memory",
+        "MetricExpr": "(UNC_CHA_REQUESTS.WRITES_REMOTE * 64 / 1000000) / duration_time",
+        "MetricGroup": "",
+        "MetricName": "llc_miss_remote_memory_bandwidth_write",
+        "ScaleUnit": "1MB/s"
     }
```

## 3.更新perf
cd perfmon
./scripts/create_perf_json.py
ad dput scripts/perf/emeraldrapids/
ad dput scripts/perf/sapphirerapids/
cd linux/tools/perf
ad dget emeraldrapids pmu-events/arch/x86/emeraldrapids
ad dget sapphirerapids pmu-events/arch/x86/sapphirerapids
make -j

# 4. Granite Rapids (Family 6 Model 0xAD) 支持

GNR 在 linux v6.14-rc3 已自带 events 但缺很多 metric。本目录 `graniterapids/`
是合并版的 PMU 数据，按 linux pmu-events 数组格式存放：

- `cache.json`、`memory.json`、`uncore-*.json` 等 events：直接复制 linux v6.14-rc3
- `gnr-metrics.json`：333 条。来源拆分：
  - 56 条 perfmon GNR perf-flavor 原版
  - 240 条从 linux 上游 EMR 移植
  - 34 条从 awesome_devops EMR 补丁（`emeraldrapids/emr-metrics.json`）移植，
    与 EMR/SPR 自定义指标一一对应（tma_bottleneck_*、tma_code_stlb_*、
    tma_load_stlb_miss_*、tma_ms、tma_fp_divider 等）
  - 3 条 awesome_devops 同名 metric 的 GNR 化版本

  移植时做了 GNR 化适配：
  - `UNC_M_CAS_COUNT.RD/WR` → `UNC_M_CAS_COUNT_SCH0.RD + UNC_M_CAS_COUNT_SCH1.RD`
  - 引用 `UNC_M2M_*` 的 metric 改为只用 `UNC_CHA_DIR_UPDATE.*`（GNR 无 M2M 单元）
  - 引用 `OCR.*`、`L3_HIT.SNOOP_*` 等 GNR 没有的事件的 metric 跳过
- `metricgroups.json`：与 EMR 共用

重新编译时把本目录 dput 到 linux/tools/perf/pmu-events/arch/x86/graniterapids/，
mapfile.csv 里 `GenuineIntel-6-A[DE],v1.02,graniterapids,core` 已存在无需改。
编译命令：

    make -C tools/perf WERROR=0 NO_JVMTI=1 -j$(nproc)

# 5. 二进制运行依赖

`perf_x86.bin` 是上述源码在 Debian 12 上编出的产物，动态链接：

- `libpython3.11.so.1.0`（Debian 12 / Ubuntu 22.04+ 默认有）
- `libcapstone.so.4`（Debian 12 默认有）

`perf_x86` 是同名 shell wrapper，会自动加载 `./lib/` 下 .so 兜底。如果部署到
没有 python3.11 或 capstone4 的旧系统，把对应 .so 放进 `lib/` 即可。

# 6. exporter 自动过滤不支持的 metric

`perf_stat_exporter.py` 启动时会对每个 metric 跑一次 50ms dry-run，把当前
机器实际不支持的 metric（如单 socket 机的 UPI、内核 IIO format 不全的机型）
自动剔除，避免 perf -M 整体失败。换机器/换 CPU 不需要改代码。
