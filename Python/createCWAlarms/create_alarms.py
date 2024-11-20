import boto3
import json

# Configuration
ALARM_NAME_PREFIX = "CPUTheadDump"
METRIC_NAME = "CPUUtilization"
NAMESPACE = "AWS/EC2"
THRESHOLD = 85.0  # Threshold percentage
PERIOD = 300
EVALUATION_PERIODS = 2
STATISTIC = "Average"
OUTPUT_FILE = "alarm_event_patterns.txt"
INSTANCE_IDS = [
    'i-0cbc3471f59b7ea6d',
    'i-014c4ecddbad6b7c9'

]
REGIONS = ["us-east-1", "us-west-2", "us-east-2", "us-west-1", "eu-central-1", "ca-central-1"]


def find_instance_region(instance_id):
    """
    Find the region where the instance is located by querying all specified regions.
    """
    for region in REGIONS:
        print(f"Searching for {instance_id} in region {region}...")
        ec2_client = boto3.client("ec2", region_name=region)
        try:
            response = ec2_client.describe_instances(InstanceIds=[instance_id])
            if response["Reservations"]:
                return region
        except ec2_client.exceptions.ClientError as e:
            if "InvalidInstanceID" not in str(e):
                print(f"Error searching for instance in {region}: {e}")
    return None


def create_alarm(instance_id, region):
    """
    Create a CloudWatch alarm and save the event pattern to the output file.
    """
    alarm_name = f"{ALARM_NAME_PREFIX}_{instance_id}"
    cw_client = boto3.client("cloudwatch", region_name=region)

    # Create the CloudWatch alarm
    cw_client.put_metric_alarm(
        AlarmName=alarm_name,
        Namespace=NAMESPACE,
        MetricName=METRIC_NAME,
        Dimensions=[{"Name": "InstanceId", "Value": instance_id}],
        Statistic=STATISTIC,
        Period=PERIOD,
        EvaluationPeriods=EVALUATION_PERIODS,
        Threshold=THRESHOLD,
        ComparisonOperator="GreaterThanThreshold",
        AlarmDescription=f"High {METRIC_NAME} alarm for instance {instance_id}"
    )
    print(f"Created alarm for instance {instance_id} with name {alarm_name} in region {region}")

    # Generate event pattern
    event_pattern = {
        "source": ["aws.cloudwatch"],
        "detail-type": ["CloudWatch Alarm State Change"],
        "detail": {"alarmName": [alarm_name]}
    }

    # Write to output file
    with open(OUTPUT_FILE, "a") as f:
        f.write(f"Alarm created: {alarm_name} in region {region}\n")
        f.write(json.dumps(event_pattern, indent=2))
        f.write("\n\n")


def main():
    # Clear the output file
    with open(OUTPUT_FILE, "w") as f:
        pass

    # Process each instance ID
    for instance_id in INSTANCE_IDS:
        region = find_instance_region(instance_id)
        if not region:
            print(f"Instance {instance_id} not found in any region. Skipping...")
            continue
        create_alarm(instance_id, region)

    print(f"All alarms created. Event patterns saved to {OUTPUT_FILE}.")


if __name__ == "__main__":
    main()
