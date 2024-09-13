#!/bin/bash

# 定义备份目录
dir="per_openyurt_bak"
modified_dir="$dir/modified"
original_dir="$dir/original"

# 创建备份目录
mkdir -p $modified_dir $original_dir

# 导出当前的 daemonset 配置并备份到 original 目录
kubectl get daemonset.apps/ovs-ovn -n kube-system -o yaml > $original_dir/ovs-ovn-daemonset.yaml
kubectl get daemonset.apps/kube-ovn-cni -n kube-system -o yaml > $original_dir/kube-ovn-cni-daemonset.yaml
kubectl get deployment.apps/kube-ovn-controller -n kube-system -o yaml > $original_dir/kube-ovn-controller-deployment.yaml
kubectl get daemonset.apps/nodelocaldns -n kube-system -o yaml > $original_dir/nodelocaldns-daemonset.yaml
kubectl get daemonset.apps/kube-multus-ds -n kube-system -o yaml > $original_dir/kube-multus-ds-daemonset.yaml

# 复制原始文件到 modified 目录用于修改
cp $original_dir/ovs-ovn-daemonset.yaml $modified_dir/ovs-ovn-daemonset.yaml
cp $original_dir/kube-ovn-cni-daemonset.yaml $modified_dir/kube-ovn-cni-daemonset.yaml
cp $original_dir/kube-ovn-controller-deployment.yaml $modified_dir/kube-ovn-controller-deployment.yaml
cp $original_dir/nodelocaldns-daemonset.yaml $modified_dir/nodelocaldns-daemonset.yaml
cp $original_dir/kube-multus-ds-daemonset.yaml $modified_dir/kube-multus-ds-daemonset.yaml

# 使用 sed 删除包含 `effect: NoSchedule` 和 `operator: Exists` 的两行
sed -i '/effect: NoSchedule/{N;/operator: Exists/d;}' $modified_dir/ovs-ovn-daemonset.yaml
sed -i '/effect: NoSchedule/{N;/operator: Exists/d;}' $modified_dir/kube-ovn-cni-daemonset.yaml
sed -i '/effect: NoSchedule/{N;/operator: Exists/d;}' $modified_dir/kube-ovn-controller-deployment.yaml
sed -i '/effect: NoSchedule/{N;/operator: Exists/d;}' $modified_dir/nodelocaldns-daemonset.yaml
sed -i '/effect: NoSchedule/{N;/operator: Exists/d;}' $modified_dir/kube-multus-ds-daemonset.yaml

# 使用修改后的 YAML 更新 daemonset
kubectl apply -f $modified_dir/ovs-ovn-daemonset.yaml
kubectl apply -f $modified_dir/kube-ovn-cni-daemonset.yaml
kubectl apply -f $modified_dir/kube-ovn-controller-deployment.yaml
kubectl apply -f $modified_dir/nodelocaldns-daemonset.yaml
kubectl apply -f $modified_dir/kube-multus-ds-daemonset.yaml

echo "Tolerations updated successfully."
