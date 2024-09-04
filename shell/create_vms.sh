template=$(cat <<EOF
apiVersion: mececs.io/v1beta1
kind: EnhancedVirtualMachine
metadata:
  name: openyurt-edge-0001
  namespace: openyurt
spec:
  template:
    spec:
      liveUpdateFeatures:
        cpu:
          maxSockets: 64
      running: true
      template:
        metadata:
          labels:
            kubevirt.io/vm: openyurt-edge-0001
          annotations:
            ovn.kubernetes.io/allow_live_migration: 'true'
            k8s.v1.cni.cncf.io/networks: mec-nets/attachnet1,mec-nets/attachnet2
            attachnet1.mec-nets.ovn.kubernetes.io/logical_switch: ovn-default
            attachnet1.mec-nets.ovn.kubernetes.io/allow_live_migration: 'true'
        spec:
          domain:
            cpu:
              sockets: 2
              cores: 1
              threads: 1
            memory:
              guest: "4Gi"
            clock:
              timezone: "Asia/Shanghai"
              timer:
                rtc:
                  present: true
            devices:
              disks:
              - disk:
                  bus: virtio
                name: cloudinitdisk
              interfaces:
              - bridge: {}
                name: attachnet1
            resources:
              requests:
                cpu: 2
                memory: 4Gi
          dnsPolicy: "None"
          dnsConfig:
            nameservers:
              - 114.114.114.114
            options:
              - name: ndots
                value: "5"
          hostname: "openyurt-edge-0001"
          networks:
          - name: attachnet1
            multus:
              networkName: mec-nets/attachnet1
          volumes:
          - cloudInitConfigDrive:
              userData: |-
                #cloud-config
                user: root
                password: openyurt
                ssh_pwauth: True
                chpasswd: { expire: False }
            name: cloudinitdisk
  # storageClassName: ceph-rbd-sc # name of StorageClass
  source:
          registryImageURL: ecs/rocky:8
  bootVolume:
    resources:
      requests:
        storage: 15Gi
EOF
)

# 生成并应用 100 个虚拟机
for i in $(seq -f "%04g" 1 100); do
  vm_name="openyurt-edge-${i}"
  yaml_content=$(echo "$template" | sed "s/openyurt-edge-0001/$vm_name/g")
  echo "$yaml_content" | kubectl apply -f -
done

echo "100 个 EnhancedVirtualMachine 已经创建并应用到 Kubernetes 集群中。"