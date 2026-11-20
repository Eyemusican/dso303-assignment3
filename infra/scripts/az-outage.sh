#!/bin/bash
# Simulates losing AZ a for the app tier: puts the app subnet in AZ a behind a deny-all network ACL.
# usage: bash scripts/az-outage.sh start   then later   bash scripts/az-outage.sh stop
set -e
export PATH=$HOME/bin:$PATH
R=ap-southeast-1
SUBNET=$(terraform output -json app_subnet_ids | python3 -c 'import sys,json;print(json.load(sys.stdin)[0])')
VPC=$(aws ec2 describe-subnets --region $R --subnet-ids $SUBNET --query 'Subnets[0].VpcId' --output text)
assoc() { aws ec2 describe-network-acls --region $R --filters Name=association.subnet-id,Values=$SUBNET \
  --query "NetworkAcls[0].Associations[?SubnetId=='$SUBNET'].NetworkAclAssociationId" --output text; }
if [ "$1" = "start" ]; then
  # a new network ACL with no rules denies everything
  NACL=$(aws ec2 create-network-acl --region $R --vpc-id $VPC \
    --tag-specifications 'ResourceType=network-acl,Tags=[{Key=Name,Value=tenzin-a3-az-outage}]' \
    --query 'NetworkAcl.NetworkAclId' --output text)
  aws ec2 replace-network-acl-association --region $R --association-id $(assoc) --network-acl-id $NACL >/dev/null
  echo "$(date -u +%T) AZ a app subnet $SUBNET is now cut off (NACL $NACL)"
else
  DEFAULT=$(aws ec2 describe-network-acls --region $R --filters Name=vpc-id,Values=$VPC Name=default,Values=true \
    --query 'NetworkAcls[0].NetworkAclId' --output text)
  aws ec2 replace-network-acl-association --region $R --association-id $(assoc) --network-acl-id $DEFAULT >/dev/null
  for N in $(aws ec2 describe-network-acls --region $R --filters Name=tag:Name,Values=tenzin-a3-az-outage \
      --query 'NetworkAcls[].NetworkAclId' --output text); do aws ec2 delete-network-acl --region $R --network-acl-id $N; done
  echo "$(date -u +%T) AZ a restored"
fi
