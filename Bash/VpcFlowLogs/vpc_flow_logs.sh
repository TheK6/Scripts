#!/bin/bash

# Variables
account_id=$(aws sts get-caller-identity --query "Account" --output text)
role_name="VPCFlowLogsRole"
policy_name="VPCFlowLogsPolicy"
changed_vpcs_file="changed_vpcs_file.csv"

# Creating an IAM role to send logs to CloudWatch
create_iam_role() {
    if aws iam get-role --role-name $role_name &> /dev/null; then
        echo "IAM role $role_name already exists. Skipping creation."
    else
        aws iam create-role --role-name $role_name --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Service": [
                          "vpc-flow-logs.amazonaws.com"
                        ]
                    },
                    "Action": "sts:AssumeRole"
                }
            ]
        }'

        aws iam put-role-policy --role-name $role_name --policy-name $policy_name --policy-document '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": [
                        "logs:CreateLogGroup",
                        "logs:CreateLogStream",
                        "logs:PutLogEvents",
                        "logs:DescribeLogGroups",
                        "logs:DescribeLogStreams",
                        "cloudwatch:*"
                      ],
                    "Resource": "*"
                }
            ]
        }'
        echo "IAM Role $role_name created."
    fi
}


# # Checking if the VPC has instances
# check_vpc_instances() {
#     local region=$1
#     local vpc_id=$2
#     aws ec2 describe-instances --region $region --filters "Name=vpc-id,Values=$vpc_id" --query "Reservations[*].Instances[*].InstanceId" --output text
# }

# Checking if flow logs are enabled for the given VPC
check_flow_logs() {
    local region=$1
    local vpc_id=$2
    aws ec2 describe-flow-logs --region $region --filter Name=resource-id,Values=$vpc_id --query "FlowLogs" --output text
}

# Function to create a log group in CloudWatch
create_log_group() {
    local region=$1
    local log_group_name="vpc/flow-logs/$vpc_id"
    aws logs create-log-group --region $region --log-group-name $log_group_name
}

# Function to set the log group retention policy
set_log_group_retention() {
    local region=$1
    local log_group_name=$2
    local retention_days=$3
    aws logs put-retention-policy --region $region --log-group-name $log_group_name --retention-in-days $retention_days
}

# Function to create a flow log for a given VPC
create_flow_log() {
    local region=$1
    local vpc_id=$2
    local flow_log_name="ar-vpc-flowlogs-$vpc_id"
    local log_group_name="vpc/flow-logs/$vpc_id"
    aws ec2 create-flow-logs --region $region --resource-type VPC --resource-ids $vpc_id --traffic-type ALL --log-destination-type cloud-watch-logs --log-group-name $log_group_name --deliver-logs-permission-arn arn:aws:iam::$account_id:role/$role_name --tag-specifications "ResourceType="vpc-flow-log",Tags=[{Key=Name,Value=$flow_log_name}]"
    echo $log_group_name
}

# Function to process VPCs in a specific region
process_region() {
    local region=$1
    local retention_days=$2

    echo "Processing region: $region"

    vpcs=$(aws ec2 describe-vpcs --region $region --query "Vpcs[*].VpcId" --output text)
  
    for vpc_id in $vpcs; do
        echo "Checking VPC: $vpc_id in region: $region"

        # instances=$(check_vpc_instances $region $vpc_id)
        # if [ -z "$instances" ]; then
        #     echo "No instances found in VPC: $vpc_id. Skipping..."
        #     continue
        # fi

        flow_logs=$(check_flow_logs $region $vpc_id)
        if [ -n "$flow_logs" ]; then
            echo "Flow logs already enabled for VPC: $vpc_id. Skipping..."
            continue
        fi

        echo "No flow logs found for VPC: $vpc_id. Creating flow log..."
        #log_group_name=$(
        # create_flow_log $region $vpc_id
        # #)
        # log_group_name="vpc/flow-logs/$vpc_id"
        # echo "Flow log created for VPC: $vpc_id in CloudWatch log group: $log_group_name"

        # echo "Creating log group..."
        # create_log_group $region $log_group_name
        # echo "Log group $log_group_name created."

        # echo "Setting log group retention policy..."
        # set_log_group_retention $region $log_group_name $retention_days
        # echo "Log group retention policy set to $retention_days days."

        echo "$counter,$region,$vpc_id,$log_group_name" >> $changed_vpcs_file
        ((counter++))
    done
}

# Main script
if [ $# -lt 2 ]; then
    echo "Usage: $0 retention_days region1 [region2 ... | all]"
    exit 1
fi
retention_days=$1
shift

echo "Number,Region,VPC ID, LOG GROUP NAME" > $changed_vpcs_file

# Create IAM Role
create_iam_role
echo "IAM Role created"

regions=$@

if [ "$1" == "all" ]; then
    regions=$(aws ec2 describe-regions --query "Regions[*].RegionName" --output text)
fi
counter=1
for region in $regions; do
    process_region $region $retention_days
done

echo "Script execution completed. Check changed_vpcs_file.csv for details on VPCs that had flow logs enabled."