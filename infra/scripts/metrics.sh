#!/bin/bash
# Prints CloudWatch metrics per minute for the last 15 minutes (ECS CPU, ALB, RDS)
export PATH=$HOME/bin:$PATH
R=ap-southeast-1
START=$(date -u -d '-15 min' +%Y-%m-%dT%H:%M:%SZ); END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
CLUSTER=$(terraform output -raw ecs_cluster); SERVICE=$(terraform output -raw ecs_service)
LB=$(aws elbv2 describe-target-groups --region $R --target-group-arns $(terraform output -raw alb_target_group_arn) \
     --query 'TargetGroups[0].LoadBalancerArns[0]' --output text | sed 's/.*:loadbalancer\///')
DB=$(terraform output -raw db_identifier)

m() { # namespace metric stat dims...
  echo "== $1 $2 ($3) =="
  aws cloudwatch get-metric-statistics --region $R --namespace $1 --metric-name $2 --statistics $3 \
    --period 60 --start-time $START --end-time $END --dimensions "${@:4}" \
    --query 'sort_by(Datapoints,&Timestamp)[].[Timestamp,'"$3"']' --output text
}
m AWS/ECS CPUUtilization Maximum Name=ClusterName,Value=$CLUSTER Name=ServiceName,Value=$SERVICE
m AWS/ApplicationELB TargetResponseTime Average Name=LoadBalancer,Value=$LB
m AWS/ApplicationELB RequestCount Sum Name=LoadBalancer,Value=$LB
m AWS/ApplicationELB HTTPCode_ELB_5XX_Count Sum Name=LoadBalancer,Value=$LB
m AWS/RDS CPUUtilization Maximum Name=DBInstanceIdentifier,Value=$DB
m AWS/RDS DatabaseConnections Maximum Name=DBInstanceIdentifier,Value=$DB
