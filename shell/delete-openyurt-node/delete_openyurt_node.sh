#!/bin/bash

# 定义要删除的节点和虚拟机数量
NUM_NODES=100

# 删除指定数量的节点
for i in $(seq -f "%04g" 1 $NUM_NODES); do
  vm_name="openyurt-edge-${i}"
  kubectl delete node $vm_name 
done

echo "$NUM_NODES 个节点已经从 Kubernetes 集群中删除。"

sleep 20

# 删除指定数量的虚拟机
for i in $(seq -f "%04g" 1 $NUM_NODES); do
  vm_name="openyurt-edge-${i}"
  kubectl delete evm $vm_name --namespace=openyurt
done

echo "$NUM_NODES 个 EnhancedVirtualMachine 已经从 Kubernetes 集群中删除。"
