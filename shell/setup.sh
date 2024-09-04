#!/bin/bash

set -e
set -o pipefail

ARCH=$(uname -m)

case $ARCH in
  "x86_64")
    ARCH="amd64"
    ;;
  "aarch64")
    ARCH="arm64"
    ;;
esac

CUR=$(realpath $(dirname $0))

#kube/runc/cni/crictl
CNI_VERSION=v1.2.0
KUBE_FILE=$CUR/$ARCH/kube/kube.tar.gz
CNI_FILE=$CUR/$ARCH/cni/cni-plugins-linux-$ARCH-$CNI_VERSION.tgz
RUNC_FILE=$CUR/$ARCH/runc/runc
CRICTL_FILE=$CUR/$ARCH/crictl/crictl

# containerd
CONTAINERD_PATH=$CUR/$ARCH/containerd
CONTAINERD_VERSION=1.6.4
CONTAINERD_FILE=$CONTAINERD_PATH/containerd-$CONTAINERD_VERSION-linux-$ARCH.tar.gz
CONTAINERD_CONFIG_FILE=$CONTAINERD_PATH/config.toml
CONTAINERD_SYSTEM_FILE=$CONTAINERD_PATH/containerd.service
CONTAINERD_CRICTL_CONFIG_FILE=$CONTAINERD_PATH/crictl.yaml

function init_os() {
    if grep -q "Ubuntu" /etc/lsb-release; then
        cat > /etc/systemd/network/10-dummy0.netdev <<EOF
[NetDev]
Name=dns-dummy0
Kind=dummy
EOF
        cat > /etc/systemd/network/20-dummy0.network  <<EOF
[Match]
Name=dns-dummy0

[Network]
Address=169.254.25.10/32
EOF
        systemctl  restart systemd-networkd
    else
        nmcli connection add type dummy con-name dns-dummy0 ifname dns-dummy0 autoconnect yes
        nmcli connection modify dns-dummy0 ipv4.addresses 169.254.25.10/32 ipv4.method manual
        nmcli connection up dns-dummy0
    fi

    modinfo br_netfilter > /dev/null 2>&1
    if [ $? -eq 0 ]; then
       modprobe br_netfilter
       mkdir -p /etc/modules-load.d
       echo 'br_netfilter' > /etc/modules-load.d/br_netfilter.conf
    fi
    
    modinfo overlay > /dev/null 2>&1
    if [ $? -eq 0 ]; then
       modprobe overlay
       echo 'overlay' >> /etc/modules-load.d/br_netfilter.conf
    fi
    
    modprobe ip_vs
    modprobe ip_vs_rr
    modprobe ip_vs_wrr
    modprobe ip_vs_sh
    modprobe nf_conntrack
    modprobe iptable_nat
    modprobe iptable_raw
    modprobe iptable_filter
    modprobe iptable_mangle
    
    cat > /etc/modules-load.d/kube_proxy-ipvs.conf << EOF
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
iptable_nat
iptable_raw
iptable_filter
iptable_mangle
EOF
    
    if [ -f /etc/selinux/config ]; then
      sed -ri 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
    fi
    
    if command -v setenforce &> /dev/null
    then
      setenforce 0 || true
    fi

   cat > /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
net.ipv4.tcp_tw_recycle=0
vm.swappiness=0
vm.overcommit_memory=1
vm.panic_on_oom=0
EOF

    sysctl --system
}

#PS3="请选择要安装的东西（输入对应的数字）: "
#options=("init os" "安装containerd" "安装docker" "安装k8s client" "allin" "退出")


function install_containerd() {
    echo "installing containerd binary..."
    if [[ -f $CONTAINERD_FILE ]]; then
	tar --strip-components=1 -xvf $CONTAINERD_FILE -C /usr/bin/
    else
	echo "$CONTAINERD_FILE file not exists!!"
	exit 1
    fi

    if [[ ! -f "/usr/local/sbin/runc" ]]; then
        echo "install runc..."
        if [[ -f $RUNC_FILE ]]; then
            cp $RUNC_FILE /usr/local/sbin/
        fi
    fi

    echo "install circtl..."
    if [[ -f $CRICTL_FILE ]] && [[ -f $CONTAINERD_CRICTL_CONFIG_FILE ]]; then
	cp $CRICTL_FILE /usr/bin/
	cp $CONTAINERD_CRICTL_CONFIG_FILE /etc/
    fi

    echo "install cni..."
    if [[ -f $CNI_FILE ]]; then
	mkdir -p /opt/cni/bin
	tar -xvf $CNI_FILE -C /opt/cni/bin/ 
    fi

    echo "starting containerd service"
    if [[ -f $CONTAINERD_CONFIG_FILE ]] && [[ -f $CONTAINERD_SYSTEM_FILE ]]; then
	cp $CONTAINERD_SYSTEM_FILE /etc/systemd/system/
        mkdir -p /etc/containerd
	cp $CONTAINERD_CONFIG_FILE /etc/containerd/
	systemctl enable --now containerd
	systemctl restart containerd
    fi
}

function install_k8s_client() {
    echo "installing kube binary..."
    if [[ -f $KUBE_FILE  ]]; then
	tar -xvf $KUBE_FILE -C /usr/local/bin/
	cp /usr/local/bin/kubelet /usr/bin/
	#tar --strip-components=1 -xvf $KUBE_FILE -C /usr/local/bin/
    else
	echo "$KUBE_FILE file not exists!!"
        exit 1
    fi
    echo "Kube binary install success!!"
}


function install_docker() {
    # TODO
    echo "未实现"
    exit 1
}


yum_install(){
    yum_opts="--disablerepo=* --enablerepo=local"
    yum -y $yum_opts install $@
}


function setup_centos_repo() {
    cat <<EOF > /etc/yum.repos.d/local.repo
[local]
name=local repo from filesystem
baseurl=file://$CUR//$ARCH/centos_repo
enabled=0
gpgcheck=0
EOF

    if ! command -v iptables &> /dev/null; then
        yum_install iptables
    fi
	
    if ! command -v conntrack &> /dev/null; then
	yum_install conntrack
    fi
}

function setup_ubuntu_repo() {
    echo "deb [trusted=yes] file:///$CUR//$ARCH/ubuntu_`awk -F '"' '/VERSION_ID/ {print $2}' /etc/os-release`  archives/"| sudo tee /etc/apt/sources.list 
    apt update
    if ! command -v iptables &> /dev/null; then
        apt install iptables -y
    fi

    if command -v conntrack &> /dev/null; then
        apt install  conntrack -y
    fi
}

ME=$(basename "$0")

usage(){
    cat<<EOF
Usage:

    $ME [options]

Options:

    -h, --help           Show this usage information.
    -s, --server         The address of apiserver
    -t, --token          Bootstrap token
    -n, --node-type      Node type，can be cloud or edge, default edge
    -c, --cri-socket     Runtime of the edge node, can be docker, containerd, default containerd
    -l, --node-label     Sets the labels for joining node
EOF
}

SHORT_OPTS="s:t:n:c:l:h"
LONG_OPTS="server:,token:,node-type:,cri-socket:,node-label:,help"


ARGS=$(getopt -o "${SHORT_OPTS}" -l "${LONG_OPTS}" --name "$ME" -- "$@") || { usage >&2; exit 2; }
eval set -- "$ARGS"

while true; do
  case "$1" in
    -s|--server)
      server_ip=$2
      shift 2
      ;;
    -t|--token)
      token=$2
      shift 2
      ;;
    -n|--node-type)
      node_type=$2
      shift 2
      ;;
    -c|--cri-socket)
      cri_socket=$2
      shift 2
      ;;
    -l|--node-label)
      node_label=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "error parameters, please use help doc!"
      exit 1
      ;;
  esac
done

if [ -f /etc/redhat-release ]; then
    setup_centos_repo
fi

if [ -f /etc/lsb-release ]; then
    if grep -q "Ubuntu" /etc/lsb-release; then
        setup_ubuntu_repo
    fi
fi

init_os

if [ -z "${cri_socket}" ]; then
    cri_socket="/run/containerd/containerd.sock"
    install_containerd
elif [ ${cri_socket} == "containerd" ]; then
    echo "install containerd.."
    install_containerd
    cri_socket="/run/containerd/containerd.sock"
elif [ ${cri_socket} == "docker" ]; then
    install_docker
    cri_socket="/run/docker.sock"
else
    echo "Please input correct cri!"
    exit 1;
fi

if [ -z "${node_type}" ]; then
    node_type="edge"
elif [ ${node_type} == "cloud" ] || [ ${node_type} == "edge" ]; then
    echo "${node_type}"
else
    echo "Please input correct node_type!"
    exit 1;
fi

install_k8s_client
    
# joining the node to cloud cluster
#yurtadm join $server_ip --token=$token --node-type=$node_type --cri-socket=$cri_socket --node-labels=$node_label --discovery-token-unsafe-skip-ca-verification --reuse-cni-bin --register-with-taints="node.openyurt.io/role=edge:NoSchedule"  --v=5
