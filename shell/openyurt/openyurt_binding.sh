#!/bin/bash

# Loop from 1 to 100
for i in $(seq -w 1 100)
do
  # Construct the node name
  node_name="openyurt-edge-0$i"

  # Execute the kubectl patch command
  kubectl patch node $node_name --type='merge' -p '{"metadata":{"annotations":{"apps.openyurt.io/binding":"true"}}}'

  # Optional: Print the status
  echo "Patched $node_name"
done
for i in $(seq -w 1 100)
do
  # Construct the node name
  node_name="openyurt-edge-0$i"

  # Execute the kubectl patch command
  kubectl get node node_name -o jsonpath='{.metadata.annotations.apps\.openyurt\.io\/binding}'

done