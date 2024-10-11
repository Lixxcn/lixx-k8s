import os
import re

# 运行命令并获取输出
command = "kubectl get vmi -n openyurt"
output = os.popen(command).read()

# 正则表达式匹配第四列的IP地址
ips = re.findall(r'\b(?:\d{1,3}\.){3}\d{1,3}\b', output)

# 生成hosts文件内容
hosts_content = "[all]\n"
for ip in ips:
    hosts_content += f"{ip} ansible_password=openyurt@test\n"

# 写入到文件
with open("hosts", "w") as file:
    file.write(hosts_content)

print("文件'hosts'已生成")
