#!/bin/bash
if ! hash aws 2>/dev/null || ! hash kubectl 2>/dev/null || ! hash eksctl 2>/dev/null; then
    echo "This script requires the AWS cli, kubectl, and eksctl installed"
    exit 2
fi

set -eo pipefail

ROLE_ARN=$(aws cloudformation describe-stacks --stack-name eks-lambda-python --query "Stacks[0].Outputs[?OutputKey=='Role'].OutputValue" --output text)
CLUSTER_NAME=$(cat cluster-name.txt)

echo
echo Cluster: $CLUSTER_NAME
echo RoleArn: $ROLE_ARN
echo
AUTH_MODE=$(aws eks describe-cluster --name $CLUSTER_NAME | jq -r .cluster.accessConfig.authenticationMode)
if [[ $AUTH_MODE == "CONFIG_MAP" ]]; then
  echo ==========
  echo Change authentication mode to use access entries to use API_AND_CONFIG_MAP
  echo ==========

  while true; do
      read -p "Do you want to change authentication mode to API_AND_CONFIG_MAP? (y/n)" response
      case $response in
          [Yy]* ) aws eks update-cluster-config --name $CLUSTER_NAME --access-config authenticationMode=API_AND_CONFIG_MAP 1>/dev/null; break;;
          [Nn]* ) break;;
          * ) echo "Response must start with y or n.";;
      esac
  done
fi

echo
echo ==========
echo Create access entry
echo ==========
echo
while true; do
    read -p "Do you want create the access entry for $ROLE_ARN? (y/n)" response
    case $response in
        [Yy]* ) aws eks create-access-entry --cluster-name $CLUSTER_NAME --principal-arn $ROLE_ARN 1>/dev/null; break;;
        [Nn]* ) break;;
        * ) echo "Response must start with y or n.";;
    esac
done

echo
echo ==========
echo Associate access policy with access entry
echo ==========
echo
while true; do
    read -p "Do you want associate AmazonEKSViewPolicy access policy? (y/n)" response
    case $response in
        [Yy]* ) aws eks associate-access-policy --cluster-name $CLUSTER_NAME --principal-arn $ROLE_ARN \
          --access-scope type=namespace,namespaces=default \
          --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy 1>/dev/null; break;;
        [Nn]* ) break;;
        * ) echo "Response must start with y or n.";;
    esac
done

