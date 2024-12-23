#!/bin/bash

# 脚本名称: script_name.sh
# 脚本功能: 描述脚本的作用

# 设置错误处理
set -e          # 一旦出现错误，脚本立即退出
set -u          # 使用未定义变量时，脚本退出
set -o pipefail # 管道中的命令出错时，脚本退出

# 打印日志
log() {
  echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 定义一些常量或变量
# 读取 /etc/os-release 文件并获取操作系统名称
if [ -f /etc/os-release ]; then
  . /etc/os-release
  os_name=$NAME
  os_version=$VERSION
  os_id=$ID
else
  os_name="Unknown"
  os_version="Unknown"
  os_id="Unknown"
fi

# 判断操作系统
log "Operating System: $os_name $os_version $os_id"

function pre_install() {
  hostname=$(hostname)
  ip_address=$(hostname -I | awk '{print $1}')
  if [ -z "$ip_address" ]; then
    echo "Error: Unable to get IP address."
    exit 1
  fi
  # 将当前主机名和 IP 地址追加到 /etc/hosts 文件
  echo "$ip_address $hostname" | sudo tee -a /etc/hosts >/dev/null

  echo "Added $hostname with IP $ip_address to /etc/hosts."

  apt update
  apt install -y iptables chrony lvm2 wget net-tools \
    lrzsz make cmake curl unzip \
    sudo wget vim autoconf automake \
    openssh-server socat ipvsadm conntrack telnet \
    apt-transport-https ca-certificates gpg

  modprobe br_netfilter
  echo "modprobe br_netfilter" >>/etc/profile
  cat >/etc/sysctl.d/k8s.conf <<end
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
end
  sysctl -p /etc/sysctl.d/k8s.conf
  sysctl net.ipv4.ip_forward
  sysctl net.bridge.bridge-nf-call-iptables

  ufw disable
  swapoff -a
  # 获取文件的最后一行行号
  last_line=$(wc -l </etc/fstab)
  # 注释掉最后一行
  sed -i "${last_line}s/^/#/" /etc/fstab
  systemctl stop apparmor && systemctl disable apparmor
  iptables -F

  mkdir -p /etc/sysconfig/modules
  cat >/etc/sysconfig/modules/ipvs.modules <<'EOF'
#!/bin/bash
ipvs_modules="ip_vs ip_vs_lc ip_vs_wlc ip_vs_rr ip_vs_wrr ip_vs_lblc ip_vs_lblcr ip_vs_dh ip_vs_sh ip_vs_nq ip_vs_sed ip_vs_ftp nf_conntrack"
for kernel_module in ${ipvs_modules}; do
  /sbin/modinfo -F filename ${kernel_module} > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    /sbin/modprobe ${kernel_module}
  else
    echo "Module ${kernel_module} not found."
  fi
done
EOF

  chmod 755 /etc/sysconfig/modules/ipvs.modules
  /etc/sysconfig/modules/ipvs.modules
  lsmod | grep ip_vs
}

# 安装containerd并配置
function containerd_install() {
  log "containerd install..."
  apt install -y containerd

  log "containerd config..."
  systemctl start containerd && systemctl enable containerd && systemctl status containerd --no-pager
  mkdir -p /etc/containerd/
  containerd config default >/etc/containerd/config.toml
  sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
  sed -i 's/registry.k8s.io/k8s.lixx.cn/' /etc/containerd/config.toml
  sed -i '/\[plugins\."io.containerd.grpc.v1.cri"\.registry\]/{
  n
  s|config_path = ""|config_path = "/etc/containerd/certs.d"|
}' /etc/containerd/config.toml
  ## 配置docker加速
  mkdir -p /etc/containerd/certs.d/docker.io
  cat <<'EOF' | sudo tee /etc/containerd/certs.d/docker.io/hosts.toml >/dev/null
server = "https://docker.io"
[host."https://f53b08bd6f1d4f2984315f58f20ad38b.mirror.swr.myhuaweicloud.com"]
  capabilities = ["pull", "resolve"]

[host."https://ymjcp0nc.mirror.aliyuncs.com"]
  capabilities = ["pull", "resolve"]

[host."https://docker.m.daocloud.io"]
  capabilities = ["pull", "resolve"]
EOF
  ## registry.k8s.io
  mkdir -p /etc/containerd/certs.d/registry.k8s.io
  cat <<'EOF' | sudo tee /etc/containerd/certs.d/registry.k8s.io/hosts.toml >/dev/null
server = "https://registry.k8s.io"
[host."https://k8s.m.daocloud.io"]
  capabilities = ["pull", "resolve"]
EOF
  ## k8s.gcr.io
  sudo mkdir -p /etc/containerd/certs.d/k8s.gcr.io
  cat <<'EOF' | sudo tee /etc/containerd/certs.d/k8s.gcr.io/hosts.toml >/dev/null
server = "https://k8s.gcr.io"
[host."k8s-gcr.m.daocloud.io"]
  capabilities = ["pull", "resolve"]
EOF
  ## 命令验证
  systemctl restart containerd
}

function k8s_install_one() {
  mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

  apt update
  apt install -y cri-tools kubernetes-cni
  cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
debug: false
pull-image-on-create: false
EOF
}

function k8s_install_two() {
  apt-get install -y kubelet kubeadm kubectl
  apt-mark hold kubelet kubeadm kubectl
  systemctl enable kubelet && systemctl is-enabled kubelet
  kubeadm config images list
  # registry.aliyuncs.com/google_containers
  kubeadm init --pod-network-cidr=10.244.0.0/16 --image-repository registry.aliyuncs.com/google_containers

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
  kubectl get node -owide -A
  cd ~
  wget https://os.lixx.cn/k8s/kube-flannel.yml
  kubectl apply -f ~/kube-flannel.yml
  kubectl get po -owide -A
  kubectl taint nodes $(kubectl get nodes --selector='node-role.kubernetes.io/control-plane' -o=jsonpath='{.items[0].metadata.name}') node-role.kubernetes.io/control-plane:NoSchedule-

  cat <<EOF | sudo tee ~/simple-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    app.kubernetes.io/name: MyApp
spec:
  containers:
  - name: nginx
    image: hub.lixx.cn/library/nginx:1.14.2
    ports:
    - containerPort: 80
EOF

  cat <<EOF | sudo tee ~/my-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    app.kubernetes.io/name: MyApp
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 80
EOF
  # kubectl apply -f ~/simple-pod.yaml
  # kubectl apply -f ~/my-service.yaml
}

# 主执行部分
log "脚本开始执行"

if [ -z "${1+x}" ]; then
  echo "未提供参数，使用默认行为。"
  set -- "default" # 设置默认值
fi

# 执行功能函数
if [ "$1" == "pre" ]; then
  log "初始化系统 安装containerd crictl 不安装k8s。"
  pre_install
  containerd_install
  k8s_install_one
else
  log "完整安装。"
  pre_install
  containerd_install
  k8s_install_one
  k8s_install_two
fi

log "脚本执行完毕"
