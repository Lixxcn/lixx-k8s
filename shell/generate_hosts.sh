#!/bin/bash

# 运行命令并获取输出
output=$(kubectl get vmi -n openyurt)

# 提取第四列的IP地址并生成hosts文件内容
echo "[all]" > hosts
echo "$output" | awk '{print $4}' | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | while read ip; do
    echo "$ip ansible_password=openyurt@test" >> hosts
done

echo "文件'hosts'已生成"
