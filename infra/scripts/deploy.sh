#!/bin/bash
# Deploys the A3 stack to Singapore from AWS CloudShell.
# usage (from the infra folder): bash scripts/deploy.sh
set -e
export PATH=$HOME/bin:$PATH
export TF_PLUGIN_CACHE_DIR=/tmp/tf-cache   # keep providers out of the 1 GB CloudShell home
mkdir -p $TF_PLUGIN_CACHE_DIR

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=ap-southeast-1
REPO=${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/tenzin-a3-api

terraform init -input=false -backend-config="bucket=tenzin-a2-tfstate-${ACCOUNT_ID}"

# the ECR repo must exist before the image can be pushed
terraform apply -input=false -auto-approve -target=aws_ecr_repository.api

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin ${REPO%%/*}
docker build -t $REPO:v1 ../app/api
docker push $REPO:v1

terraform apply -input=false -auto-approve -var="image_tag=v1" "$@"

aws ecs wait services-stable --region $REGION \
  --cluster $(terraform output -raw ecs_cluster) --services $(terraform output -raw ecs_service)
echo "Site: $(terraform output -raw cloudfront_url)"
