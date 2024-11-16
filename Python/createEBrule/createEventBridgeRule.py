import boto3
import re
import json

# Input file containing the event patterns and other configurations
INPUT_FILE = "alarm_event_patterns.txt"

# AWS configuration
ACCOUNT_ID = "261140574810"  # Replace with your AWS account ID
SSM_DOCUMENT_NAME = "arm-thread-dumps-dev"  # Replace with your SSM Document name
EVENTBRIDGE_RULE_ROLE = "arn:aws:iam::261140574810:role/Eventbridge_SSM_Permissions"

with open(INPUT_FILE, "r") as file:
    event_pattern = ""
    brace_count = 0  # Counter to track JSON completeness
    region = None
    alarm_name = ""
    instance_id = ""

    for line in file:
        # Check if the line indicates alarm creation with region info
        if line.startswith("Alarm created:"):
            # Extract alarm name, instance ID, and region
            alarm_name_match = re.search(r'CPUTheadDumpTest_[^ ]*', line)
            instance_id_match = re.search(r'i-[0-9a-fA-F]+', line)
            region_match = re.search(r'(?<=region )\S+$', line.strip())

            # Validate and assign extracted information
            if alarm_name_match and instance_id_match and region_match:
                alarm_name = alarm_name_match.group(0)
                instance_id = instance_id_match.group(0)
                region = region_match.group(0)
                rule_name = f"{alarm_name}_rule"
                print(f"Creating EventBridge rule '{rule_name}' in region {region} for instance {instance_id}...")
            else:
                print(f"Could not parse alarm details from line: {line}")
                continue

        # Accumulate the lines for the JSON event pattern
        if "{" in line:
            brace_count += line.count("{")  # Increment for every opening brace
        if "}" in line:
            brace_count -= line.count("}")  # Decrement for every closing brace

        # Only add lines that are part of the JSON
        if brace_count > 0 or "}" in line:
            event_pattern += line.strip()

        # Check if the JSON is complete (all braces balanced)
        if brace_count == 0 and event_pattern.strip():
            try:
                # Validate the event pattern
                event_pattern_json = json.loads(event_pattern)

                # Create EventBridge client in the appropriate region
                client = boto3.client("events", region_name=region)

                # Create the EventBridge rule
                rule_arn = client.put_rule(
                    Name=rule_name,
                    EventPattern=json.dumps(event_pattern_json),  # Use validated JSON
                    Description=f"Event rule for alarm {alarm_name} targeting instance {instance_id}"
                )["RuleArn"]

                # Define the target for SSM document execution with role and instance ID
                target_arn = f"arn:aws:ssm:{region}:{ACCOUNT_ID}:document/{SSM_DOCUMENT_NAME}"
                target = {
                    "Id": "1",
                    "Arn": target_arn,
                    "RoleArn": EVENTBRIDGE_RULE_ROLE,
                    "RunCommandParameters": {
                        "RunCommandTargets": [
                            {
                                "Key": "InstanceIds",
                                "Values": [instance_id]
                            }
                        ]
                    }
                }

                # Attach the target to the EventBridge rule
                client.put_targets(Rule=rule_name, Targets=[target])

                print(f"Successfully created EventBridge rule '{rule_name}' with target in region {region} for instance {instance_id}.")

            except json.JSONDecodeError as json_error:
                print(f"Invalid JSON event pattern for alarm '{alarm_name}': {event_pattern}")
                print(f"Error: {json_error}")
            except boto3.exceptions.Boto3Error as boto3_error:
                print(f"Error creating rule or setting target: {boto3_error}")

            # Reset the pattern and region after creating each rule
            event_pattern = ""
            brace_count = 0
            region = None
            alarm_name = ""
            instance_id = ""