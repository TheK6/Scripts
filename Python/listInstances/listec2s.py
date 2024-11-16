import boto3
import csv

def get_instance_name(instance):
    # Finds Name Tags
    for tag in instance.tags or []:
        if tag['Key'] == 'Name':
            return tag['Value']
    return 'N/A'  # Return 'N/A' if tag 'Name' is not found

def list_instances_in_all_regions_to_csv(file_name='aws_instances.csv'):
    ec2_client = boto3.client('ec2')

    # Gets Regions
    regions = [region['RegionName'] for region in ec2_client.describe_regions()['Regions']]

    # Creates CSV file
    with open(file_name, 'w', newline='') as csvfile:
        fieldnames = ['Region', 'Instance ID', 'Instance Name', 'Instance Type', 'State', 'Public IP', 'Private IP', 'Launch Time']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        
        writer.writeheader()

        # Iterates all regions
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