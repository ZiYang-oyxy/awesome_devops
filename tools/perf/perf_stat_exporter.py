#!/usr/bin/env python3
import os
import json
import subprocess
import time
import requests
import logging

g_start_time = time.time()

def get_host_ip():
    """Get IP address"""
    host_ip = os.environ.get('BYTED_HOST_IP')
    if not host_ip:
        host_ip = os.environ.get('BYTED_HOST_IPV6')
    print(f"Host IP: {host_ip}")
    return host_ip

def send_post_request(result):
    """Send POST request using curl with timeout and retry mechanism."""
    import subprocess
    import json

    url = 'https://ceres.byted.org/api/v2/aiops/card/monitor'
    #url = 'https://ceres.byted.org/api/v2/test_ceres_no_auth'
    data = json.dumps(result)
    max_retries = 2
    retries = 0
    curl_timeout = 2  # 超时时间（秒）

    while retries < max_retries:
        command = [
            'curl',
            '--location',
            '--request', 'POST',
            url,
            '--header', 'Content-Type: application/json',
            '--data-raw', data,
            '--max-time', str(curl_timeout)
        ]
        try:
            print(f"Sending POST request (attempt {retries+1}): {data}")
            # 设置 Python 超时略高于 curl 的 --max-time
            completed = subprocess.run(command, capture_output=True, text=True, check=True, timeout=curl_timeout+2)
            print(f"Successfully sent POST request: {completed.stdout}")
            break
        except subprocess.TimeoutExpired as e:
            retries += 1
            print(f"Request timed out (attempt {retries}/{max_retries}): {e}. Retrying...")
        except subprocess.CalledProcessError as e:
            retries += 1
            print(f"Error sending POST request (attempt {retries}/{max_retries}): {e.stderr}. Retrying...")
    else:
        print(f"Failed to send POST request after {max_retries} retries.")

def process_output(output):
    """Process each JSON string from the command output"""
    global g_start_time
    try:
        print(f"Raw output: {output}")
        data = json.loads(output)
        interval = data["interval"]
        timestamp = int(g_start_time + interval)
        # Get current time in a readable format
        current_time = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())

        # Print processed timestamp and current time
        print(f"{current_time} Processed timestamp: {timestamp}")

        socket = data["socket"]
        host_ip = get_host_ip()

        result = []
        for key, value in data.items():
            if key not in ["interval", "socket", "aggregate-number"]:
                # Remove leading spaces from the metric name
                name = key.split(" ", 1)[-1].strip()
                try:
                    # Check if the value is "none", then skip it
                    if value.lower() == "none":
                        continue
                    # Convert the value to a number
                    value = float(value)
                except ValueError:
                    continue

                metric_data = {
                    "metric": "cpu_perfmon",
                    "timestamp": timestamp,
                    "value": value,
                    "tags": {
                        "host_ip": host_ip,
                        "socket": socket,
                        "name": name
                    }
                }
                result.append(metric_data)

        return result
    except json.JSONDecodeError as e:
        print(f"Failed to decode JSON: {e}")
        return []

# 定义一个指标列表
metrics = [
    'tma_info_system_mem_read_latency',
    'tma_info_system_mem_dram_read_latency',
    'tma_info_memory_tlb_page_walks_utilization',
    'tma_info_memory_prefetches_useless_hwpf',
    'tma_info_system_mem_parallel_reads',
    'tma_info_system_dram_bw_use',
    'numa_reads_addressed_to_local_dram',
    'numa_reads_addressed_to_remote_dram',
    'llc_data_read_mpi_demand_plus_prefetch',
    'llc_code_read_mpi_demand_plus_prefetch',
    'llc_demand_data_read_miss_to_dram_latency',
    'llc_demand_data_read_miss_latency_for_remote_requests',
    'llc_demand_data_read_miss_latency_for_local_requests',
    'llc_demand_data_read_miss_latency',
    'stores_per_instr',
    'loads_per_instr',
    'cpi',
    'cpu_operating_frequency',
    'cpu_utilization',
    'memory_extra_write_bw_due_to_directory_updates',
    'uncore_frequency',
    'memory_bandwidth_read',
    'memory_bandwidth_write',
    'tma_info_memory_latency_data_l2_mlp',
    'tma_info_memory_latency_load_l2_mlp',
    'tma_info_memory_latency_load_l3_miss_latency',
    'tma_info_memory_latency_load_l2_miss_latency',
    'upi_tx_non_data_percent',
    'upi_data_receive_bw',
    'upi_data_transmit_bw',
    'io_percent_of_inbound_partial_writes_that_miss_l3',
    'io_percent_of_inbound_full_writes_that_miss_l3',
    'io_percent_of_inbound_reads_that_miss_l3',
    'io_bandwidth_read_remote',
    'io_bandwidth_read_local',
    'io_bandwidth_write_remote',
    'io_bandwidth_write_local',
    'iio_bandwidth_write',
    'iio_bandwidth_read',
    'llc_miss_remote_memory_bandwidth_write',
    'llc_miss_remote_memory_bandwidth_read',
    'llc_miss_local_memory_bandwidth_write',
    'llc_miss_local_memory_bandwidth_read'
]

def filter_supported_metrics(all_metrics):
    """Drop metrics that won't run on this host's PMUs.

    perf -M aborts the entire run if ANY metric is unresolvable, so we
    must prune up-front. We probe each metric in bulk via a short dry-run
    of `perf stat -M <one>` and drop any that hits 'Bad event or PMU' /
    'Unable to find PMU' / 'value too big for format'. The probe runs
    sequentially per metric for ~50ms each, so 40 metrics ≈ 2s startup.
    """
    kept = []
    dropped = []
    for m in all_metrics:
        try:
            r = subprocess.run(
                ['ad', 'perf', 'perf_x86', 'stat', '-a', '-M', m,
                 '--per-socket', '--metric-only', '-x', ',', '--', 'sleep', '0.05'],
                capture_output=True, text=True, timeout=8,
            )
            err = r.stderr or ''
            bad = ('Bad event or PMU' in err
                   or 'Unable to find PMU' in err
                   or 'value too big for format' in err
                   or 'Cannot find metric or group' in err
                   or 'event syntax error' in err)
            if bad:
                # extract first short reason
                reason = 'probe failed'
                for line in err.splitlines():
                    line = line.strip()
                    if any(tag in line for tag in ('Bad event', 'Unable to find', 'value too big', 'Cannot find metric', 'syntax error')):
                        reason = line[:120]
                        break
                dropped.append((m, reason))
            else:
                kept.append(m)
        except subprocess.TimeoutExpired:
            dropped.append((m, 'probe timeout'))
        except Exception as e:
            dropped.append((m, f'probe error: {e}'))
    if dropped:
        print(f"Dropped {len(dropped)} unsupported metrics on this host:")
        for m, why in dropped:
            print(f"  - {m}  ({why})")
    print(f"Active metrics: {len(kept)}/{len(all_metrics)}")
    return kept


def run_command():
    """Run the command and process its output continuously"""
    global g_start_time
    active_metrics = filter_supported_metrics(metrics)
    command = [
        'ad', 'perf', 'perf_x86', 'stat', '-a',
        '-M', ','.join(active_metrics),
        '--per-socket', '-j', '--metric-only', '-I', '1950'
    ]

    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    g_start_time = time.time()

    while True:
        # Read the error output of the command line by line (stderr)
        output = process.stderr.readline()
        if output:
            decoded_output = output.decode().strip()
            # Process the JSON output
            result = process_output(decoded_output)
            if result:
                send_post_request(result)

        # Sleep for a short time before reading again to prevent high CPU usage
        time.sleep(0.1)

if __name__ == "__main__":
    try:
        run_command()
    except KeyboardInterrupt:
        print("\nProgram interrupted. Exiting...")
