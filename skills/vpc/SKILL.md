---
name: vpc
description: Manage AWS VPC networking — VPCs, subnets, route tables, NAT gateways, internet gateways, and network ACLs via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🌐",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Amazon VPC

Use this skill for Virtual Private Cloud networking operations: managing VPCs, subnets, route tables, internet gateways, NAT gateways, VPC peering, and network ACLs.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `ec2:*Vpc*`, `ec2:*Subnet*`, `ec2:*RouteTable*`, `ec2:*Gateway*`, `ec2:*SecurityGroup*`, `ec2:*NetworkAcl*`

## Common Operations

### List and Inspect (Read-Only)

```bash
# List all VPCs
aws ec2 describe-vpcs \
  --query 'Vpcs[].[VpcId, CidrBlock, IsDefault, Tags[?Key==`Name`].Value | [0], State]' \
  --output table

# List subnets in a VPC
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'Subnets[].[SubnetId, CidrBlock, AvailabilityZone, MapPublicIpOnLaunch, Tags[?Key==`Name`].Value | [0]]' \
  --output table

# List route tables
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'RouteTables[].[RouteTableId, Tags[?Key==`Name`].Value | [0], Associations[0].SubnetId]' \
  --output table

# Show routes for a route table
aws ec2 describe-route-tables --route-table-ids <rtb-id> \
  --query 'RouteTables[0].Routes[].[DestinationCidrBlock, GatewayId, NatGatewayId, State]' \
  --output table

# List internet gateways
aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=<vpc-id>" \
  --query 'InternetGateways[].[InternetGatewayId, Attachments[0].State]' --output table

# List NAT gateways
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=<vpc-id>" \
  --query 'NatGateways[].[NatGatewayId, State, SubnetId, ConnectivityType]' --output table

# List security groups in a VPC
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'SecurityGroups[].[GroupId, GroupName, Description]' --output table

# Show inbound rules for a security group
aws ec2 describe-security-groups --group-ids <sg-id> \
  --query 'SecurityGroups[0].IpPermissions[].[IpProtocol, FromPort, ToPort, IpRanges[].CidrIp, UserIdGroupPairs[].GroupId]'

# List VPC endpoints
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'VpcEndpoints[].[VpcEndpointId, ServiceName, VpcEndpointType, State]' --output table

# List VPC peering connections
aws ec2 describe-vpc-peering-connections \
  --filters "Name=requester-vpc-info.vpc-id,Values=<vpc-id>" \
  --query 'VpcPeeringConnections[].[VpcPeeringConnectionId, Status.Code, RequesterVpcInfo.CidrBlock, AccepterVpcInfo.CidrBlock]' \
  --output table

# Show VPC flow logs
aws ec2 describe-flow-logs --filter "Name=resource-id,Values=<vpc-id>" \
  --query 'FlowLogs[].[FlowLogId, LogDestinationType, TrafficType, LogGroupName]' --output table
```

### Create a VPC

⚠️ **Cost note:** VPCs, subnets, route tables, and internet gateways are free. NAT Gateways cost ~$32/month each plus data processing charges. Elastic IPs are free when attached, $3.65/month when unattached.

```bash
# Create a VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=my-vpc}]' \
  --query 'Vpc.VpcId' --output text)

# Enable DNS hostnames (required for many services)
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames '{"Value": true}'

# Create public subnets (one per AZ for high availability)
PUB_SUB_1=$(aws ec2 create-subnet --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 --availability-zone <region>a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=public-a}]' \
  --query 'Subnet.SubnetId' --output text)

PUB_SUB_2=$(aws ec2 create-subnet --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 --availability-zone <region>b \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=public-b}]' \
  --query 'Subnet.SubnetId' --output text)

# Create private subnets
PRIV_SUB_1=$(aws ec2 create-subnet --vpc-id $VPC_ID \
  --cidr-block 10.0.10.0/24 --availability-zone <region>a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=private-a}]' \
  --query 'Subnet.SubnetId' --output text)

PRIV_SUB_2=$(aws ec2 create-subnet --vpc-id $VPC_ID \
  --cidr-block 10.0.11.0/24 --availability-zone <region>b \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=private-b}]' \
  --query 'Subnet.SubnetId' --output text)

# Create and attach internet gateway
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=my-igw}]' \
  --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID

# Create public route table with internet route
PUB_RTB=$(aws ec2 create-route-table --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=public-rt}]' \
  --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $PUB_RTB --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
aws ec2 associate-route-table --route-table-id $PUB_RTB --subnet-id $PUB_SUB_1
aws ec2 associate-route-table --route-table-id $PUB_RTB --subnet-id $PUB_SUB_2

# Auto-assign public IPs on public subnets
aws ec2 modify-subnet-attribute --subnet-id $PUB_SUB_1 --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $PUB_SUB_2 --map-public-ip-on-launch
```

### NAT Gateway (for Private Subnet Internet Access)

⚠️ **Cost note:** NAT Gateways cost ~$0.045/hr (~$32/month) per gateway plus $0.045/GB processed. For dev environments, consider NAT instances or VPC endpoints instead.

```bash
# Allocate an Elastic IP
EIP_ALLOC=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)

# Create NAT gateway in a public subnet
NAT_ID=$(aws ec2 create-nat-gateway --subnet-id $PUB_SUB_1 --allocation-id $EIP_ALLOC \
  --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=my-nat}]' \
  --query 'NatGateway.NatGatewayId' --output text)

aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_ID

# Add route in private route table
PRIV_RTB=$(aws ec2 create-route-table --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=private-rt}]' \
  --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $PRIV_RTB --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_ID
aws ec2 associate-route-table --route-table-id $PRIV_RTB --subnet-id $PRIV_SUB_1
aws ec2 associate-route-table --route-table-id $PRIV_RTB --subnet-id $PRIV_SUB_2
```

### Delete / Destructive

🛑 **DESTRUCTIVE — VPC deletion requires removing all dependent resources first. Always confirm.**

```bash
# Delete a NAT gateway (stops ~$32/month cost)
aws ec2 delete-nat-gateway --nat-gateway-id <nat-gw-id>

# Release Elastic IP (after NAT gateway is deleted)
aws ec2 release-address --allocation-id <eip-alloc-id>

# Delete a subnet (must be empty)
aws ec2 delete-subnet --subnet-id <subnet-id>

# Detach and delete internet gateway
aws ec2 detach-internet-gateway --internet-gateway-id <igw-id> --vpc-id <vpc-id>
aws ec2 delete-internet-gateway --internet-gateway-id <igw-id>

# Delete a VPC (must have no dependencies)
aws ec2 delete-vpc --vpc-id <vpc-id>
```

## Safety Rules

1. **NEVER** delete a VPC or subnet without confirming it has no running resources.
2. **NEVER** add `0.0.0.0/0` inbound rules to security groups on SSH/RDP ports.
3. **ALWAYS** confirm the VPC and region before making changes.
4. **ALWAYS** use at least 2 AZs for high availability in production.
5. **ALWAYS** tag subnets as public or private for clarity.
6. **WARN** about NAT Gateway costs before creation (~$32/month each).
7. **WARN** about Elastic IP charges when IPs are not attached to running instances.
8. **PREFER** VPC endpoints over NAT gateways for AWS service access (cheaper, faster, more secure).

## Best Practices

- Use at least 2 AZs for production workloads.
- Keep databases and application tiers in private subnets.
- Use VPC endpoints for S3, DynamoDB, and other AWS services to avoid NAT costs and improve security.
- Enable VPC Flow Logs for security auditing.
- Use /16 CIDR for VPCs and /24 for subnets to allow growth.
- Plan CIDR ranges to avoid overlap if you'll need VPC peering or Transit Gateway.

## Common Patterns

### Pattern: Audit Security Group Exposure

```bash
# Find security groups with 0.0.0.0/0 inbound rules
aws ec2 describe-security-groups \
  --query 'SecurityGroups[?IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]].[GroupId, GroupName, IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]].[FromPort, ToPort, IpProtocol]]' \
  --output json
```

### Pattern: Find Unused Elastic IPs (Cost Waste)

```bash
aws ec2 describe-addresses \
  --query 'Addresses[?!InstanceId && !NetworkInterfaceId].[PublicIp, AllocationId]' \
  --output table
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `DependencyViolation` on delete | Resources still using the VPC/subnet | Remove all EC2 instances, ENIs, LBs, NAT GWs first |
| `InvalidVpcID.NotFound` | VPC doesn't exist in this region | Verify VPC ID and region |
| No internet from private subnet | Missing NAT gateway or route | Check route table has 0.0.0.0/0 -> NAT gateway |
| No internet from public subnet | Missing IGW or route | Check route table has 0.0.0.0/0 -> IGW and subnet auto-assigns public IPs |
| `SubnetLimitExceeded` | Too many subnets in VPC | Request a limit increase via Service Quotas |
