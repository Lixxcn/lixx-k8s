#!/bin/bash

sudo swapoff -a

modprobe br_netfilter
echo "modprobe br_netfilter" >> /etc/profile
cat > /etc/sysctl.d/k8s.conf << end
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
end
sysctl -p /etc/sysctl.d/k8s.conf
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables


sudo systemctl stop apparmor && systemctl disable apparmor

for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do apt-get remove $pkg; done
apt-get update
apt-get install ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install containerd.io -y

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.tuna.tsinghua.edu.cn/kubernetes/core:/stable:/v1.30/deb/ /
EOF

apt update
apt install kubelet kubeadm iptables chrony -y
iptables -F
sudo systemctl enable chrony
sudo systemctl start chrony
chronyc tracking
chronyc sources
sudo timedatectl set-timezone Asia/Shanghai
timedatectl

mkdir -p /etc/sysconfig/modules
cat > /etc/sysconfig/modules/ipvs.modules << 'EOF'
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

chmod 755 /etc/sysconfig/modules/ipvs.modules #调整模式
/etc/sysconfig/modules/ipvs.modules # 执⾏
lsmod | grep ip_vs
systemctl start containerd && systemctl enable containerd 
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sed -i '/\[plugins."io.containerd.grpc.v1.cri".registry\]/{
    N; s|config_path = ""|config_path = "/etc/containerd/certs.d"|
}' /etc/containerd/config.toml
mkdir -p /etc/containerd/certs.d/docker.io
cat <<'EOF' | sudo tee /etc/containerd/certs.d/docker.io/hosts.toml > /dev/null
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
cat <<'EOF' | sudo tee /etc/containerd/certs.d/registry.k8s.io/hosts.toml > /dev/null
server = "https://registry.k8s.io"
[host."https://k8s.m.daocloud.io"]
  capabilities = ["pull", "resolve"]
EOF
## k8s.gcr.io
sudo mkdir -p /etc/containerd/certs.d/k8s.gcr.io
cat <<'EOF' | sudo tee /etc/containerd/certs.d/k8s.gcr.io/hosts.toml > /dev/null
server = "https://k8s.gcr.io"
[host."k8s-gcr.m.daocloud.io"]
  capabilities = ["pull", "resolve"]
EOF
systemctl restart containerd && systemctl status containerd






