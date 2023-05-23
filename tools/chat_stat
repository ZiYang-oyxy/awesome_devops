#!/usr/bin/env python3
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
from collections import defaultdict
import csv
from datetime import datetime
import re

hourly_logs = {}

# 读取文件，统计每小时的日志数量
with open('chat.log', 'r') as f:
    pattern = r'\[Time\]\s+(\d+\/\d+\/\d+),\s+(\d+:\d+:\d+)'
    for line in f:
        match = re.search(pattern, line)
        if match:
            line = line.strip()
            log_time = datetime.strptime(line[8:30], '%m/%d/%Y, %I:%M:%S %p')
            hour = log_time.strftime('%Y-%m-%d %H')
            if hour in hourly_logs:
                hourly_logs[hour] += 1
            else:
                hourly_logs[hour] = 1

# 输出CSV文件
with open('chat.csv', mode='w', newline='') as file:
    writer = csv.writer(file, delimiter=' ')
    writer.writerow(['data', 'hour', 'count'])
    for hour, count in hourly_logs.items():
        writer.writerow([hour, count])


# 用一个字典来存储每天每小时的计数
count_dict = defaultdict(int)

# 读取文件
with open('chat.csv') as csvfile:
    csvreader = csv.reader(csvfile)
    next(csvreader)  # 跳过文件的头行
    for row in csvreader:
        row = row[0].split()
        # 解析每行中的日期和小时数
        date = row[0]
        hour = int(row[1])
        # 在字典中增加计数
        count_dict[(date, hour)] += int(row[2])

# 将字典转换为DataFrame
data = pd.DataFrame(list(count_dict.items()), columns=['date_hour', 'count'])
data['date'] = data['date_hour'].apply(lambda x: x[0])
data['hour'] = data['date_hour'].apply(lambda x: x[1])
data = data.drop(['date_hour'], axis=1)
data = data.pivot(index='hour', columns='date', values='count')

# 绘制热力图
plt.figure(figsize=(8, 4))
sns.heatmap(data, cmap='YlOrRd', annot=True, fmt='.0f', annot_kws={"size": 6})
# 设置日期格式和标签旋转角度
plt.xticks(rotation=45, fontsize=4)  # 修改旋转角度和字体大小
plt.title('chat count', fontsize=10)
plt.xlabel('day', fontsize=8)
plt.ylabel('hour', fontsize=8)
plt.tick_params(axis='both', labelsize=6)
# plt.show()
plt.savefig('chat.svg', format='svg')
