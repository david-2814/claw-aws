---
name: eks
description: Manage Amazon EKS clusters, node groups, Fargate profiles, and kubeconfig via AWS CLI and kubectl.
metadata:
  {
    "openclaw":
      {
        "emoji": "☸️",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Amazon EKS

Use this skill for Kubernetes on AWS: creating and managing EKS clusters, configuring node groups and Fargate profiles, updating kubeconfig, managing add-ons, and troubleshooting cluster access.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `eks:*` for full access, or scoped policies
- `kubectl` installed for cluster interaction
- Optional: `eksctl` for simplified cluster management

## Common Operations

### List and Inspect (Read-Only)

```bash
# List all clusters
aws eks list-clusters --query 'clusters' --output table

# Describe a cluster
aws eks describe-cluster --name <cluster-name> \
  --query 'cluster.{Name:name,Status:status,Version:version,Endpoint:endpoint,PlatformVersion:platformVersion}'

# List node groups
aws eks list-nodegroups --cluster-name <cluster-name>

# Describe a node group
aws eks describe-nodegroup \
  --cluster-name <cluster-name> \
  --nodegroup-name <nodegroup-name> \
  --query 'nodegroup.{Name:nodegroupName,Status:status,InstanceTypes:instanceTypes,Desired:scalingConfig.desiredSize,Min:scalingConfig.minSize,Max:scalingConfig.maxSize}'

# List Fargate profiles
aws eks list-fargate-profiles --cluster-name <cluster-name>

# Describe a Fargate profile
aws eks describe-fargate-profile \
  --cluster-name <cluster-name> \
  --fargate-profile-name <profile-name>

# List add-ons
aws eks list-addons --cluster-name <cluster-name>

# Describe an add-on
aws eks describe-addon \
  --cluster-name <cluster-name> \
  --addon-name <addon-name>

# List available add-on versions
aws eks describe-addon-versions \
  --addon-name <addon-name> \
  --kubernetes-version <k8s-version> \
  --query 'addons[0].addonVersions[].addonVersion'

# Check cluster authentication mode
aws eks describe-cluster --name <cluster-name> \
  --query 'cluster.accessConfig'

# List access entries (EKS API auth)
aws eks list-access-entries --cluster-name <cluster-name>
```

### Configure kubectl

```bash
# Update kubeconfig (sets current context)
aws eks update-kubeconfig --name <cluster-name> --region <region>

# Update kubeconfig with a specific role
aws eks update-kubeconfig --name <cluster-name> --region <region> \
  --role-arn arn:aws:iam::<account-id>:role/<role-name>

# Verify connectivity
kubectl get nodes
kubectl cluster-info
```

### Create / Update

⚠️ **Cost note:** EKS control plane costs $0.10/hour (~$73/month). Node costs depend on EC2 instance types. Fargate charges per vCPU and GB per second.

```bash
# Create a cluster (basic — use eksctl for production setups)
aws eks create-cluster \
  --name <cluster-name> \
  --role-arn <cluster-role-arn> \
  --resources-vpc-config subnetIds=<subnet-1>,<subnet-2>,securityGroupIds=<sg-id> \
  --kubernetes-version 1.29

# Wait for cluster to become active
aws eks wait cluster-active --name <cluster-name>

# Create a managed node group
aws eks create-nodegroup \
  --cluster-name <cluster-name> \
  --nodegroup-name <nodegroup-name> \
  --node-role <node-role-arn> \
  --subnets <subnet-1> <subnet-2> \
  --instance-types t3.medium \
  --scaling-config minSize=2,maxSize=5,desiredSize=3 \
  --disk-size 20

# Wait for node group to become active
aws eks wait nodegroup-active \
  --cluster-name <cluster-name> \
  --nodegroup-name <nodegroup-name>

# Create a Fargate profile
aws eks create-fargate-profile \
  --cluster-name <cluster-name> \
  --fargate-profile-name <profile-name> \
  --pod-execution-role-arn <fargate-role-arn> \
  --subnets <private-subnet-1> <private-subnet-2> \
  --selectors namespace=<namespace>

# Install an add-on
aws eks create-addon \
  --cluster-name <cluster-name> \
  --addon-name vpc-cni \
  --resolve-conflicts OVERWRITE

# Update cluster Kubernetes version
aws eks update-cluster-version \
  --name <cluster-name> \
  --kubernetes-version <new-version>

# Update node group scaling
aws eks update-nodegroup-config \
  --cluster-name <cluster-name> \
  --nodegroup-name <nodegroup-name> \
  --scaling-config minSize=2,maxSize=10,desiredSize=5

# Grant access to an IAM principal (EKS API auth)
aws eks create-access-entry \
  --cluster-name <cluster-name> \
  --principal-arn <iam-principal-arn> \
  --type STANDARD

aws eks associate-access-policy \
  --cluster-name <cluster-name> \
  --principal-arn <iam-principal-arn> \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete a node group (drains nodes first)
aws eks delete-nodegroup \
  --cluster-name <cluster-name> \
  --nodegroup-name <nodegroup-name>

# Wait for node group deletion
aws eks wait nodegroup-deleted \
  --cluster-name <cluster-name> \
  --nodegroup-name <nodegroup-name>

# Delete a Fargate profile
aws eks delete-fargate-profile \
  --cluster-name <cluster-name> \
  --fargate-profile-name <profile-name>

# Delete an add-on
aws eks delete-addon \
  --cluster-name <cluster-name> \
  --addon-name <addon-name>

# Delete a cluster (must delete node groups and Fargate profiles first)
aws eks delete-cluster --name <cluster-name>
```

⚠️ **You must delete all node groups, Fargate profiles, and add-ons before deleting the cluster.**

## Safety Rules

1. **NEVER** delete a cluster without listing all node groups, Fargate profiles, and workloads first.
2. **NEVER** expose or log AWS credentials, access keys, or kubeconfig tokens.
3. **ALWAYS** confirm the cluster name and region before any write operations.
4. **ALWAYS** warn that Kubernetes version upgrades are irreversible.
5. **ALWAYS** recommend upgrading node groups after upgrading the control plane.
6. **WARN** about cost implications — EKS + nodes can be expensive at scale.

## Best Practices

- Use managed node groups for automatic OS updates and simplified lifecycle.
- Place nodes in private subnets; use a NAT gateway for outbound traffic.
- Enable cluster logging (api, audit, authenticator, controllerManager, scheduler).
- Use EKS access entries (API auth) instead of aws-auth ConfigMap for simpler IAM mapping.
- Keep clusters within one minor version of the latest Kubernetes release.

## Common Patterns

### Pattern: Quick Cluster with eksctl

```bash
# Create a production-ready cluster (if eksctl is installed)
eksctl create cluster \
  --name <cluster-name> \
  --region <region> \
  --version 1.29 \
  --managed \
  --nodegroup-name workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 5
```

### Pattern: Enable Cluster Logging

```bash
aws eks update-cluster-config \
  --name <cluster-name> \
  --logging '{
    "clusterLogging": [{
      "types": ["api", "audit", "authenticator", "controllerManager", "scheduler"],
      "enabled": true
    }]
  }'
```

### Pattern: Upgrade Cluster Step-by-Step

```bash
CLUSTER="<cluster-name>"
NEW_VERSION="1.30"

# 1. Update control plane
aws eks update-cluster-version --name $CLUSTER --kubernetes-version $NEW_VERSION
aws eks wait cluster-active --name $CLUSTER

# 2. Update each node group
for NG in $(aws eks list-nodegroups --cluster-name $CLUSTER --query 'nodegroups[]' --output text); do
  aws eks update-nodegroup-version --cluster-name $CLUSTER --nodegroup-name $NG
  aws eks wait nodegroup-active --cluster-name $CLUSTER --nodegroup-name $NG
done

# 3. Update add-ons
for ADDON in $(aws eks list-addons --cluster-name $CLUSTER --query 'addons[]' --output text); do
  LATEST=$(aws eks describe-addon-versions --addon-name $ADDON --kubernetes-version $NEW_VERSION \
    --query 'addons[0].addonVersions[0].addonVersion' --output text)
  aws eks update-addon --cluster-name $CLUSTER --addon-name $ADDON --addon-version $LATEST --resolve-conflicts PRESERVE
done
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `ResourceNotFoundException` | Cluster doesn't exist in this region | Verify with `list-clusters` and check region |
| `error: You must be logged in` | kubeconfig not configured | Run `aws eks update-kubeconfig --name <cluster>` |
| `Unauthorized` in kubectl | IAM principal not mapped | Add access entry or update aws-auth ConfigMap |
| `ResourceInUseException` | Cluster has node groups or profiles | Delete node groups and Fargate profiles first |
| Node group `CREATE_FAILED` | Subnet or IAM role issues | Check subnets have available IPs; verify node role has required policies |
| Pods stuck in `Pending` | No capacity or Fargate selector mismatch | Check node scaling or Fargate profile namespace selectors |
