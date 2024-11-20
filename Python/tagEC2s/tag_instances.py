import boto3

# Input the required information here
INSTANCE_IDS = [
    'i-087f7e50a17c4f721',
    'i-02d2cb48f70aeb18c',
    'i-0db794393028468f6',
    'i-01d1130a967f9db04',
    'i-02cd56028f45a1122'
]  
TAGS = {
    "arm_crash_dump": "true"
}  # Replace with your key-value pairs
REGIONS = ['us-east-1', 'us-west-1', 'us-east-2', 'us-west-2', 'eu-central-1', 'ap-south-1']  # List of AWS regions to search

def find_instance_region(instance_id, regions):
    """
    Finds the region where a specific EC2 instance exists.

    :param instance_id: The ID of the instance to locate.
    :param regions: List of AWS regions to search.
    :return: The region where the instance is found, or None if not found.
    """
    for region in regions:
        ec2_client = boto3.client('ec2', region_name=region)
        try:
            response = ec2_client.describe_instances(InstanceIds=[instance_id])
            if response['Reservations']:
                return region
        except Exception:
            pass  # Ignore exceptions for regions where the instance is not found
    return None

def tag_instances(instance_ids, tags, regions):
    """
    Tags EC2 instances with the specified keys and values.

    :param instance_ids: List of instance IDs to tag.
    :param tags: Dictionary of key-value pairs to use as tags.
    :param regions: List of AWS regions to search.
    """
    formatted_tags = [{'Key': key, 'Value': value} for key, value in tags.items()]
    instances_to_tag = {}

    # Find the region for each instance
    for instance_id in instance_ids:
        region = find_instance_region(instance_id, regions)
        if region:
            if region not in instances_to_tag:
                instances_to_tag[region] = []
            instances_to_tag[region].append(instance_id)
        else:
            print(f"Instance {instance_id} not found in any region. Skipping...")

    # Tag the instances in their respective regions
    for region, ids in instances_to_tag.items():
        ec2_client = boto3.client('ec2', region_name=region)
        try:
            ec2_client.create_tags(Resources=ids, Tags=formatted_tags)
            print(f"Successfully tagged instances {ids} in region {region} with {tags}")
        except Exception as e:
            print(f"Failed to tag instances {ids} in region {region}: {e}")

if __name__ == "__main__":
    if not INSTANCE_IDS:
        print("Error: No instance IDs provided. Please update the script with the required instance IDs.")
    elif not TAGS:
        print("Error: No tags provided. Please update the script with the required tags.")
    else:
        tag_instances(INSTANCE_IDS, TAGS, REGIONS)
