import boto3
import csv
from datetime import datetime

def get_instance_name(instance):
    # Finds Name Tags
    for tag in instance.tags or []:
        if tag['Key'] == 'Name':
            return tag['Value']
    return 'N/A'  # Return 'N/A' if tag 'Name' is not found

def list_instances_in_all_regions_to_csv():
    ec2_client = boto3.client('ec2')
    sts_client = boto3.client('sts')

    # Get the AWS Account ID
    account_id = sts_client.get_caller_identity()["Account"]

    # Get today's date
    today = datetime.now().strftime('%Y-%m-%d')

    # Generate file name
    file_name = f"aws_instances_{account_id}_{today}.csv"

    # Get Regions
    regions = [region['RegionName'] for region in ec2_client.describe_regions()['Regions']]

    # Create CSV file
    with open(file_name, 'w', newline='') as csvfile:
        fieldnames = ['Region', 'Instance ID', 'Instance Name', 'Instance Type', 'State', 'Public IP', 'Private IP', 'Launch Time']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        
        writer.writeheader()

        # Iterate through all regions
        for region in regions:
            ec2 = boto3.resource('ec2', region_name=region)
            instances = ec2.instances.all()

            for instance in instances:
                instance_name = get_instance_name(instance)
                writer.writerow({
                    'Region': region,
                    'Instance ID': instance.id,
                    'Instance Name': instance_name,
                    'Instance Type': instance.instance_type,
                    'State': instance.state['Name'],
                    'Public IP': instance.public_ip_address or 'N/A',
                    'Private IP': instance.private_ip_address or 'N/A',
                    'Launch Time': instance.launch_time
                })

    print(f"Instance information has been saved to {file_name}.")

if __name__ == "__main__":
    list_instances_in_all_regions_to_csv()