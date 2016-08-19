#cloud-config

---
write-files:
  - path: /etc/conf.d/nfs
    permissions: '0644'
    content: |
      OPTS_RPC_MOUNTD=""
  - path: /opt/bin/wupiao
    permissions: '0755'
    content: |
      #!/bin/bash
      # [w]ait [u]ntil [p]ort [i]s [a]ctually [o]pen
      [ -n "$1" ] && \
        until curl -o /dev/null -sIf http://$${1}; do \
          sleep 1 && echo .;
        done;
      exit $?
  - path: /root/.vault-token
    permissions: 0644
    content: |
      ${vault_token}
  - path: /root/.credentials
    permissions: 0644
    content: |
      ${initial_admin_token},admin,admin
      kubelet,kubelet,kubelet
      scheduler,scheduler,scheduler
      pong,ping,health
  - path: /opt/auth-policy.jsonl
    permissions : 0644
    content: |
      {"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"*", "nonResourcePath": "/healthz", "readonly": true}}
      {"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"admin", "namespace": "*", "resource": "*", "apiGroup": "*",  "nonResourcePath": "*"}}
      {"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"scheduler", "namespace": "*", "resource": "*", "apiGroup": "*", "nonResourcePath": "*"}}
      {"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"kubelet", "namespace": "*", "resource": "*", "apiGroup": "*", "nonResourcePath": "*"}}
      {"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"group":"system:serviceaccounts", "namespace": "*", "resource": "*", "apiGroup": "*", "nonResourcePath": "*"}}
  - path: /etc/hosts
    permissions: 0755
    content: |
      ${node1IP} node1k8s.services.schubergphilis.com
      ${node2IP} node2k8s.services.schubergphilis.com
      ${node3IP} node3k8s.services.schubergphilis.com
  - path: /opt/bin/read-vault.sh
    permissions: 0755
    content: |
      #!/bin/bash
      
      /opt/bin/vault read -address=https://saas.vault.schubergphilis.com:8201 -field=$2 $1 > $3

coreos:
  fleet:
    metadata: "role=master"
  flannel:
      etcd_endpoints: "https://node1k8s.services.schubergphilis.com:2379,https://node2k8s.services.schubergphilis.com:2379,https://node3k8s.services.schubergphilis.com:2379"
  units:
    - name: vault.service
      command: start
      content: |
        [Unit]
        Description=Vault download and enable

        [Service]
        ExecStartPre=/usr/bin/wget https://releases.hashicorp.com/vault/0.5.2/vault_0.5.2_linux_amd64.zip -P /tmp
        ExecStart=/usr/bin/unzip /tmp/vault_0.5.2_linux_amd64.zip -d /opt/bin/

        ExecStartPost=/opt/bin/read-vault.sh secret/k8smgt/prod/app/${clustername}/ca.pem value /opt/ca.pem
        ExecStartPost=/opt/bin/read-vault.sh secret/k8smgt/prod/app/${clustername}/apiserver.pem value /opt/apiserver.pem
        ExecStartPost=/opt/bin/read-vault.sh secret/k8smgt/prod/app/${clustername}/apiserver-key.pem value /opt/apiserver-key.pem
        ExecStartPost=/opt/bin/read-vault.sh secret/k8smgt/prod/app/${clustername}/kube-serviceaccount.key value /opt/kube-serviceaccount.key
        ExecStartPost=/opt/bin/read-vault.sh secret/k8smgt/prod/app/${clustername}/cloud-config value /opt/cloud-config

        RemainAfterExit=yes
        Type=oneshot
    - name: setup-network-environment.service
      command: start
      content: |
        [Unit]
        Description=Setup Network Environment
        Documentation=https://github.com/kelseyhightower/setup-network-environment
        Requires=network-online.target
        After=network-online.target

        [Service]
        ExecStartPre=-/usr/bin/mkdir -p /opt/bin
        ExecStartPre=/usr/bin/curl -L -o /opt/bin/setup-network-environment -z /opt/bin/setup-network-environment https://github.com/kelseyhightower/setup-network-environment/releases/download/v1.0.0/setup-network-environment
        ExecStartPre=/usr/bin/chmod +x /opt/bin/setup-network-environment
        ExecStart=/opt/bin/setup-network-environment
        RemainAfterExit=yes
        Type=oneshot
    - name: flanneld.service
      command: start
      drop-ins:
        - name: 50-network-config.conf
          content: |
            [Service]
            ExecStartPre=/usr/bin/etcdctl --endpoint=https://node1k8s.services.schubergphilis.com:2379 set /coreos.com/network/config '{"Network":"10.192.0.0/16", "Backend": {"Type": "vxlan"}}'
    - name: docker.service
      command: start
    - name: kube-apiserver.service
      command: start
      content: |
        [Unit]
        Description=Kubernetes API Server
        Documentation=https://github.com/kubernetes/kubernetes
        Requires=setup-network-environment.service vault.service
        After=setup-network-environment.service vault.service

        [Service]
        EnvironmentFile=/etc/network-environment
        ExecStartPre=-/usr/bin/mkdir -p /opt/bin
        ExecStartPre=/usr/bin/curl -L -o /opt/bin/kube-apiserver -z /opt/bin/kube-apiserver https://artifacts.schubergphilis.com/artifacts/kubernetes/v1.3.4/bin/linux/amd64/kube-apiserver
        ExecStartPre=/usr/bin/chmod +x /opt/bin/kube-apiserver
        ExecStartPre=/opt/bin/wupiao node1k8s.services.schubergphilis.com:4001/v2/machines
        ExecStart=/opt/bin/kube-apiserver \
          --service-account-key-file=/opt/kube-serviceaccount.key \
          --service-account-lookup=false \
          --admission-control=NamespaceLifecycle,NamespaceAutoProvision,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota \
          --apiserver-count=3 \
          --authorization-mode=ABAC \
          --authorization-policy-file=/opt/auth-policy.jsonl \
          --token-auth-file=/root/.credentials \
          --allow-privileged=true \
          --insecure-bind-address=0.0.0.0 \
          --bind-address=0.0.0.0 \
          --insecure-port=8080 \
          --kubelet-https=true \
          --secure-port=6443 \
          --cloud-provider=cloudstack \
          --cloud-config=/opt/cloud-config \
          --tls-cert-file="/opt/apiserver.pem" \
          --tls-private-key-file="/opt/apiserver-key.pem" \
          --service-cluster-ip-range=10.100.0.0/24 \
          --etcd-servers=https://node1k8s.services.schubergphilis.com:2379,https://node2k8s.services.schubergphilis.com:2379,https://node3k8s.services.schubergphilis.com:2379 \
          --v=2 \
          --logtostderr=true
        Restart=always
        RestartSec=10
    - name: kube-controller-manager.service
      command: start
      content: |
        [Unit]
        Description=Kubernetes Controller Manager
        Documentation=https://github.com/kubernetes/kubernetes
        Requires=kube-apiserver.service
        After=kube-apiserver.service

        [Service]
        EnvironmentFile=/etc/network-environment
        ExecStartPre=/usr/bin/curl -L -o /opt/bin/kube-controller-manager -z /opt/bin/kube-controller-manager https://artifacts.schubergphilis.com/artifacts/kubernetes/v1.3.4/bin/linux/amd64/kube-controller-manager
        ExecStartPre=/usr/bin/chmod +x /opt/bin/kube-controller-manager
        ExecStart=/opt/bin/kube-controller-manager \
          --service-account-private-key-file=/opt/kube-serviceaccount.key \
          --master=$${DEFAULT_IPV4}:8080 \
          --leader-elect=true \
          --cluster-name=nl2-k8s \
          --logtostderr=true \
          --cloud-provider=cloudstack \
          --cloud-config=/opt/cloud-config \
          --root-ca-file="/opt/ca.pem" \
          --v=2
        Restart=always
        RestartSec=10
    - name: kube-scheduler.service
      command: start
      content: |
        [Unit]
        Description=Kubernetes Scheduler
        Documentation=https://github.com/kubernetes/kubernetes
        Requires=kube-apiserver.service
        After=kube-apiserver.service

        [Service]
        EnvironmentFile=/etc/network-environment
        ExecStartPre=/usr/bin/curl -L -o /opt/bin/kube-scheduler -z /opt/bin/kube-scheduler https://artifacts.schubergphilis.com/artifacts/kubernetes/v1.3.4/bin/linux/amd64/kube-scheduler
        ExecStartPre=/usr/bin/chmod +x /opt/bin/kube-scheduler
        ExecStart=/opt/bin/kube-scheduler \
          --master=$${DEFAULT_IPV4}:8080 \
          --leader-elect=true \
          --v=2
        Restart=always
        RestartSec=10
    - name: splunk-forwarder-container.service
      command: start
      content: |
        [Unit]
        Description=Splunk forwarder Container for journalctl
        [Service]
        ExecStartPre=/bin/sh -c 'echo 85.222.236.236 registry.services.schubergphilis.com >>/etc/hosts'
        ExecStart=/usr/bin/docker run -d -h %H --name splunk \
          -v /var/log/splunk:/var/log/splunk \
          -e SPLUNK_INPUTPATH_1=/var/log/splunk/journald.log \
          -e SPLUNK_INPUTPATH_1__SOURCETYPE=json \
          -e SPLUNK_HOST=31.22.84.40 \
          registry.services.schubergphilis.com:5000/saas/splunk-forwarder:test
    - name: journalctl-to-splunklog.service
      command: start
      content: |
        [Unit]
        Description=Journalctl json export to logfile for splunk
        [Service]
        ExecStartPre=/bin/sh -c 'mkdir -p /var/log/splunk'
        ExecStart=/bin/bash -c '/usr/bin/journalctl -f -o json >> /var/log/splunk/journald.log'
  update:
    group: alpha
    reboot-strategy: off
