#!/bin/bash

# 删除 100 个节点
for i in $(seq -f "%04g" 1 100); do
  vm_name="openyurt-edge-${i}"
  kubectl delete node $vm_name 
done

echo "100 个 节点 已经从 Kubernetes 集群中删除。"

sleep 20

# 删除 100 个虚拟机
for i in $(seq -f "%04g" 1 100); do
  vm_name="openyurt-edge-${i}"
  kubectl delete evm $vm_name --namespace=openyurt
done

echo "100 个 EnhancedVirtualMachine 已经从 Kubernetes 集群中删除。"