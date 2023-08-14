#!/usr/bin/env python3
import csv
import datetime
import matplotlib.pyplot as plt
import matplotlib.dates as mdates  # 导入日期格式化程序
import re
import os
import argparse

repo_path = "/ad_files/"
g_file_stat = {}
u_results = {}
d_results = {}


def parse_log_file(log_file_path, action):
    if action == "GET":
        status_code = "200"
        cnt_str = "get_cnt"
    if action == "PUT":
        status_code = "201"
        cnt_str = "put_cnt"
    with open(log_file_path) as f:
        lines = f.readlines()

    pattern = r'\[(\d{2})/([a-zA-Z]{3})/(\d{4})\s(\d{2}):(\d{2}):(\d{2})\] "\w{3} (.*) HTTP/1.1" (\d{3})'
    results = {}
    for line in lines:
        # breakpoint()
        match = re.search(pattern, line)
        if match:
            day = match.group(1)
            month = match.group(2)
            year = match.group(3)
            file = match.group(7)
            code = match.group(8)
            file = os.path.basename(file)

            if code != status_code:
                continue

            date = datetime.datetime.strptime(f"{year}-{month}-{day}", '%Y-%b-%d')
            date_str = date.strftime('%Y%m%d')
            if date_str in results:
                results[date_str] += 1
            else:
                results[date_str] = 1

            if file not in g_file_stat:
                g_file_stat[file] = {
                    'create_date': date_str,
                    'get_cnt': 0,
                    'put_cnt': 0,
                    'access_count': 0}
            g_file_stat[file]['access_count'] += 1
            g_file_stat[file][cnt_str] += 1

    return results


def parse_post_log(log_file_path):
    phase = 0
    with open(log_file_path) as f:
        lines = f.readlines()

    pattern1 = r'\[(\d{2})/([a-zA-Z]{3})/(\d{4})\s(\d{2}):(\d{2}):(\d{2})\] "POST / HTTP/1.1" 200'
    pattern2 = r'^Received file \'(.*)\' from .*'
    for line in lines:
        if phase == 0:
            match = re.search(pattern1, line)
            if match:
                phase = 1
                day = match.group(1)
                month = match.group(2)
                year = match.group(3)
            continue
        if phase == 1:
            match = re.search(pattern2, line)
            if match:
                phase = 2
                file = match.group(1)
                file = os.path.basename(file)
            else:
                phase = 0
            continue
        if phase == 2:
            date = datetime.datetime.strptime(f"{year}-{month}-{day}", '%Y-%b-%d')
            date_str = date.strftime('%Y%m%d')
            if date_str in u_results:
                u_results[date_str] += 1
            else:
                u_results[date_str] = 1

            if file not in g_file_stat:
                g_file_stat[file] = {
                    'create_date': date_str,
                    'get_cnt': 0,
                    'put_cnt': 0,
                    'access_count': 0}
            g_file_stat[file]['access_count'] += 1
            g_file_stat[file]['put_cnt'] += 1
            phase = 0


parser = argparse.ArgumentParser()
parser.add_argument('-c', '--cleanup', action='store_true', help='execute cleanup task')
args = parser.parse_args()
opt_cleanup = args.cleanup

# Example1:
# 10.145.18.28 - - [09/Aug/2023 10:23:45] "PUT /summary.py HTTP/1.1" 100 -
# 10.145.18.28 - - [09/Aug/2023 10:23:45] "PUT /summary.py HTTP/1.1" 201 -
# Example2:
# 10.14.117.46 - - [08/Aug/2023 01:36:04] "POST / HTTP/1.1" 200 -
# Received file '/ad_files/jquery-3.7.0.min.js' from 10.14.117.46.
u_results = parse_log_file("./@servefile_u.log@", 'PUT')
parse_post_log("./@servefile_u.log@")

# Example:
# 10.93.232.17 - - [09/Aug/2023 10:51:34] "GET /dpu_monitor.tar.gz HTTP/1.1" 401 -
# 10.93.232.17 - - [09/Aug/2023 10:51:34] "GET /dpu_monitor.tar.gz HTTP/1.1" 200 -
# filetype=.gz
# 10.93.232.17 finished downloading /ad_files/dpu_monitor.tar.gz
d_results = parse_log_file("./@servefile_d.log@", 'GET')

# 将旧的未被日志跟踪的文件加到列表，供下面清理
for root, dirs, files in os.walk(repo_path):
    date = datetime.datetime.strptime("2023-3-25", '%Y-%m-%d')
    date_str = date.strftime('%Y%m%d')
    for file in files:
        file = os.path.basename(file)
        if file not in g_file_stat:
            g_file_stat[file] = {
                'create_date': date_str,
                'get_cnt': 0,
                'put_cnt': 1,
                'access_count': 1}

# 文件访问统计
now = datetime.datetime.now()
cleanup_tot_size = 0
with open('file_access_stat.csv', mode='w', newline='') as file:
    file2 = open('recommended_cleanup_file_list.csv', mode='w', newline='')
    writer = csv.writer(file)
    writer2 = csv.writer(file2)
    writer.writerow(['AccessCount', 'PutCount', 'GetCount', 'FileName', 'CreateDate', 'Size'])
    writer2.writerow(['AccessCount', 'PutCount', 'GetCount', 'FileName', 'CreateDate', 'Size'])
    for item in sorted(g_file_stat.items(), key=lambda x: x[1]['access_count'], reverse=True):
        filepath = repo_path + item[0]
        if not os.path.exists(filepath):
            continue

        filesize = os.path.getsize(filepath)

        writer.writerow(
            [item[1]['access_count'],
             item[1]['put_cnt'],
             item[1]['get_cnt'],
             item[0],
             item[1]['create_date'],
             filesize])

        # 低频访问的文件，加到推荐清理的文件列表
        date_object = datetime.datetime.strptime(item[1]['create_date'], "%Y%m%d")
        if now - date_object >= datetime.timedelta(30) and item[1]['get_cnt'] == 0:
            cleanup_tot_size += filesize
            writer2.writerow(
                [item[1]['access_count'],
                    item[1]['put_cnt'],
                    item[1]['get_cnt'],
                    item[0],
                    item[1]['create_date'],
                    filesize])
            if opt_cleanup:
                print("remove ", filepath, " ...")
                os.remove(filepath)
    print("Free up space:", cleanup_tot_size / 1024 / 1024 / 1024, "GB")

# 输出上传下载统计
with open('file_operations.csv', mode='w', newline='') as file:
    writer = csv.writer(file)
    writer.writerow(['Date', 'Uploads', 'Downloads'])
    for date in sorted(set(u_results.keys()) | set(d_results.keys())):
        u_count = u_results.get(date, 0)
        d_count = d_results.get(date, 0)
        writer.writerow([date, u_count, d_count])

# 绘制条状图并保存为SVG文件
with open('file_operations.csv', mode='r') as file:
    reader = csv.reader(file)
    next(reader)  # 跳过标题行
    dates = []
    uploads = []
    downloads = []
    for row in reader:
        date_obj = datetime.datetime.strptime(row[0], "%Y%m%d")  # 把字符串转成日期对象
        if now - date_obj >= datetime.timedelta(90):
            continue
        u_count = int(row[1])
        d_count = int(row[2])
        dates.append(date_obj)
        uploads.append(u_count)
        downloads.append(d_count)

fig, ax = plt.subplots()
fig.set_size_inches(6, 3)
ax.bar(dates, uploads, width=1, label='Uploads')
ax.bar(dates, downloads, width=1, bottom=uploads, label='Downloads')
ax.set_title('ad usage statistics', fontsize=10)
ax.set_xlabel('Date', fontsize=7)
ax.set_ylabel('Count', fontsize=7)
ax.tick_params(axis='both', labelsize=6)  # 设置刻度标签字体大小为10
ax.legend()

# 设置日期格式和标签旋转角度
date_format = mdates.DateFormatter('%Y%m%d')
plt.xticks(rotation=45, fontsize=4)  # 修改旋转角度和字体大小
ax.xaxis.set_major_formatter(date_format)

plt.savefig('file_operations.svg', format='svg')
