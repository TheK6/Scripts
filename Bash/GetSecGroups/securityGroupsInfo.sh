#!/bin/bash

# Variables
account_id=$(aws sts get-caller-identity --query "Account" --output text)
role_name="InstanceSecurityGroupScannerRole"
policy_name="InstanceSecurityGroupScannerPolicy"
output_file="instance_security_groups.csv"
instances_file="instances_id.txt"
regions=$(aws ec2 describe-regions --query "Regions[*].RegionName" --output text)

# Function to check if IAM role exists
check_iam_role() {
    echo "Checking if IAM role exists..."
    aws iam get-role --role-name $role_name >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "IAM role already exists. Skipping role creation."
        return 0
    else
        echo "IAM role does not exist. Creating IAM role..."
        return 1
    fi
}

# Function to create IAM role
create_iam_role() {
    aws iam create-role --role-name $role_name --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "ec2.amazonaws.com"
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
                    "ec2:DescribeInstances",
                    "ec2:DescribeSecurityGroups"
                ],
                "Resource": "*"
            }
        ]
    }'
    echo "IAM role created."
}

# Function to describe security groups and export to CSV
scan_instances_and_export() {
    echo "Scanning instances and exporting data to CSV..."
    echo "counter,account_number,region,instance_id,security_group_id,inbound_rules,outbound_rules" > $output_file
    counter=1

    if [ ! -f "$instances_file" ]; then
        echo "Instances file '$instances_file' not found!"
        exit 1
    fi

    while IFS= read -r instance_id; do
        echo "Processing instance: $instance_id"
        for region in $regions; do
            echo "Checking instance $instance_id in region: $region"
            security_groups=$(aws ec2 describe-instances --region $region --instance-ids $instance_id --query "Reservations[*].Instances[*].SecurityGroups[*].GroupId" --output text 2>/dev/null)

            if [ -n "$security_groups" ]; then
                for sg_id in $security_groups; do
                    inbound_rules=$(aws ec2 describe-security-groups --region $region --group-ids $sg_id --query "SecurityGroups[*].IpPermissions" --output json | jq -c .[])
                    outbound_rules=$(aws ec2 describe-security-groups --region $region --group-ids $sg_id --query "SecurityGroups[*].IpPermissionsEgress" --output json | jq -c .[])

                    echo "$counter,$account_id,$region,$instance_id,$sg_id,$inbound_rules,$outbound_rules" >> $output_file
                    counter=$((counter + 1))
                done
                break
            fi
        done
    done < "$instances_file"

    echo "Data exported to $output_file."
}

# Main script
check_iam_role
if [ $? -ne 0 ]; then
    create_iam_role
fi

scan_instances_and_export
