# tf-cs-kubernetes
Terraform plan to deploy kubernetes on cloudstack

# Pre-requirements  :

safeterraform.sh
  Make sure you have the safe_terraform.sh script from https://github.schubergphilis.com/SaaS/safe_terraform

Hashicorp vault binaries
```  
  brew install vault
  terraform version
```

Hashicorp terraform binaries
```  
  brew install terraform
  terraform version
```

Kubernetes kubectl binary
```
  curl -O https://artifacts.schubergphilis.com/artifacts/kubernetes/v1.3.4/bin/darwin/amd64/kubectl
  chmod +x kubectl
```

The k8smgt prod vault project token
  Get the project token from: https://passwordsafe.sbp.lan/passwordsafe/system/ViewPassword?id=1566f320ec41310&otid=1566f320e47130f

Cloudstack API keys : 
  Put your Cloudstack api keys in `~/.terraform/nl2_cs_api_key` and `~/.terraform/nl2_cs_secret_key`

# Define some env variables with your parameters
```
export VAULT_TOKEN=xxxxx-xxxx-xxx-xxxxx-xxxxx
export VAULT_ADDR=https://saas.vault.schubergphilis.com:8201
export TF_CONSUL=31.22.84.66:8500
export TF_VAR_stack_id=sbpaapi
export TF_VAR_env=prod
```
# Generating self signed certificates
```
./ssl/generate-keys.sh certs_${TF_VAR_env}_${TF_VAR_stack_id}
```

# Writing your certificates to vault
```
cd certs_${TF_VAR_env}_${TF_VAR_stack_id}
for file in *; do 
  vault write secret/k8smgt/${TF_VAR_env}/app/${TF_VAR_stack_id}/${file} value=@${file}
done
cd ..
```

# Generate an initial kubernetes admin token 
```
  export TF_VAR_initial_admin_token=`cat /dev/urandom |tr -dc _A-Z-a-z-0-9 | head -c32`
  echo $TF_VAR_initial_admin_token
```

# Deploying a stack
Create a temporary vault token. 
```
export TF_VAR_vault_token=`vault token-create -policy=k8smgt/prod -ttl="12h" |grep 'token ' |awk '{print $2}'`
echo ${TF_VAR_vault_token}
```

Create a new discovery token and add to terraform stack specific tfvars file
```
echo "discovery_url = \"`curl 'https://discovery.etcd.io/new?size=3' | xargs echo -n`\"" >! ${TF_VAR_env}_${TF_VAR_stack_id}.tfvars
echo "clustername = \"${TF_VAR_stack_id}\"" >>${TF_VAR_env}_${TF_VAR_stack_id}.tfvars
cat ${TF_VAR_env}_${TF_VAR_stack_id}.tfvars
```

Deploy with safe_terraform
```
safe_terraform.sh plan 
safe_terraform.sh apply
```

The new workers and masters should be made available on public services DNS. Verify :
```
host ${TF_VAR_stack_id}k8s.services.schubergphilis.com
host ${TF_VAR_stack_id}k8s-master1.services.schubergphilis.com
host ${TF_VAR_stack_id}k8s-master2.services.schubergphilis.com
host ${TF_VAR_stack_id}k8s-master3.services.schubergphilis.com
host ${TF_VAR_stack_id}k8s-worker1.services.schubergphilis.com
host ${TF_VAR_stack_id}k8s-worker2.services.schubergphilis.com
host ${TF_VAR_stack_id}k8s-worker3.services.schubergphilis.com
```

# Connecting to your cluster
```
kubectl config set-cluster ${TF_VAR_stack_id}-cluster --insecure-skip-tls-verify --server=https://${TF_VAR_stack_id}k8s.services.schubergphilis.com:6443
kubectl config set-context ${TF_VAR_stack_id}-cluster --cluster=${TF_VAR_stack_id}-cluster --user=${TF_VAR_stack_id}-admin
kubectl config set-credentials ${TF_VAR_stack_id}-admin --token=${TF_VAR_initial_admin_token}
kubectl config use-context ${TF_VAR_stack_id}-cluster
kubectl get namespaces
```

# DNS Deployment
Get the internal IP of one of the masters for DNS deployment and replace this with the DNS deployment
```
ssh core@${TF_VAR_stack_id}k8s.services.schubergphilis.com ifconfig |egrep -A1 '^eth0' |grep inet |awk '{print $2}'
sed 's/10.100.0.1/xx.xx.xx.xx/g' addons/skydns-rc.yaml| kubectl create -f -
cat addons/skydns-svc.yaml| kubectl create -f -
```

