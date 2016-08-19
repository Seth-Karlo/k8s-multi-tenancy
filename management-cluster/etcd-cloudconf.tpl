#cloud-config

write_files:
  - path: /run/systemd/system/etcd2.service.d/30-certificates.conf
    permissions: 0644
    content: |
      [Service]
      Environment=ETCD_CERT_FILE=/opt/coreos.crt
      Environment=ETCD_KEY_FILE=/opt/coreos.key
  - path: /root/.vault-token
    permissions: 0644
    content: |
      ${vault_token}
  - path: /opt/bin/read-vault.sh
    permissions: 0755
    content: |
      #!/bin/bash

      /opt/bin/vault read -address=https://saas.vault.schubergphilis.com:8201 -field=$2 $1 > $3

coreos:
  units:
    - name: etcd2.service
      command: start
      drop-ins:
        - name: 10_wait_for_vault.conf
          content: |
            [Unit]
            After=vault.service
    - name: vault.service
      command: start
      content: |
        [Unit]
        Description=Vault download and enable

        [Service]
        ExecStartPre=/usr/bin/wget https://releases.hashicorp.com/vault/0.5.2/vault_0.5.2_linux_amd64.zip -P /tmp
        ExecStart=/usr/bin/unzip /tmp/vault_0.5.2_linux_amd64.zip -d /opt/bin/
        ExecStartPost=/opt/bin/read-vault.sh secret/k8smgt/prod/app/wildcard_services_schubergphilis_com.key value /opt/coreos.key
        ExecStartPost=/opt/bin/read-vault.sh secret/k8smgt/prod/app/wildcard_services_schubergphilis_com.crt value /opt/coreos.crt

        RemainAfterExit=yes
        Type=oneshot
  etcd2:
    discovery: ${terraform_discovery_url}
    advertise-client-urls: "https://${node_name}k8s.services.schubergphilis.com:2379"
    initial-advertise-peer-urls: "http://$private_ipv4:2380"
    listen-client-urls: "https://0.0.0.0:2379,http://0.0.0.0:4001"
    listen-peer-urls: "http://$private_ipv4:2380"
  fleet:
    metadata: name=${node_name}

