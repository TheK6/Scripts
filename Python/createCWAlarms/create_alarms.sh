#!/bin/bash

# Set default variables
ALARM_NAME_PREFIX="CPUTheadDumpTest"
METRIC_NAME="CPUUtilization"
NAMESPACE="AWS/EC2"
THRESHOLD=85.0  # Threshold percentage
PERIOD=300
EVALUATION_PERIODS=2
STATISTIC="Average"
OUTPUT_FILE="alarm_event_patterns.txt"
INSTANCE_IDS="i-0781c64a4a9aff104,i-0d12d26c082516927,i-0ad2cde44ace5a38f,i-0b185383923405479,i-0c5cafdda797ef3d0"  # Add instance IDs separated by commas

# Clear output file
> "$OUTPUT_FILE"

# Set regions in the desired order (replace or reorder regions as needed)
REGIONS="us-east-1 us-west-2 us-east-2 us-west-1 eu-central-1"

# Function to find instance region
find_instance_region() {
    local instance_id=$1
    local found_region=""
    for region in $REGIONS; do
        echo "Searching for $instance_id in region $region..." >&2  # Send debug output to stderr
        # Check if the instance exists in this region
        instance_exists=$(aws ec2 describe-instances --region "$region" --instance-ids "$instance_id" --query "Reservations[0].Instances[0].InstanceId" --output text 2>/dev/null)
        
        if [[ "$instance_exists" == "$instance_id" ]]; then
            found_region="$region"
            break
        fi
    done
    echo "$found_region"  # Output only the region name for capturing
}

# Create alarms for each instance ID
IFS=',' read -ra ID_ARRAY <<< "$INSTANCE_IDS"
for INSTANCE_ID in "${ID_ARRAY[@]}"; do
    # Trim spaces
    INSTANCE_ID=$(echo "$INSTANCE_ID" | xargs)

    # Find the region for the current instance
    REGION=$(find_instance_region "$INSTANCE_ID")
    
    # Check if region was found
    if [[ -z "$REGION" ]]; then
        echo "Instance $INSTANCE_ID not found in any region. Skipping..."
        continue
    fi

    # Generate unique alarm name for each instance
    ALARM_NAME="${ALARM_NAME_PREFIX}_${INSTANCE_ID}"

    # Create CloudWatch alarm in the found region
    aws cloudwatch put-metric-alarm \
        --alarm-name "$ALARM_NAME" \
        --namespace "$NAMESPACE" \
        --metric-name "$METRIC_NAME" \
        --dimensions Name=InstanceId,Value="$INSTANCE_ID" \
        --statistic "$STATISTIC" \
        --period "$PERIOD" \
        --evaluation-periods "$EVALUATION_PERIODS" \
        --threshold "$THRESHOLD" \
        --comparison-operator GreaterThanThreshold \
        --alarm-description "High $METRIC_NAME alarm for instance $INSTANCE_ID" \
        --region "$REGION"

    # Generate custom event pattern for CloudWatch event rule
    EVENT_PATTERN=$(cat <<EOF
{
  "source": ["aws.cloudwatch"],
  "detail-type": ["CloudWatch Alarm State Change"],
  "detail": {
    "alarmName": ["$ALARM_NAME"]
  }
}
EOF
)

    # Output event pattern to file
    echo "Alarm created: $ALARM_NAME in region $REGION" >> "$OUTPUT_FILE"
    echo "$EVENT_PATTERN" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    echo "Created alarm for instance $INSTANCE_ID with name $ALARM_NAME in region $REGION"
done

echo "All alarms created. Event patterns saved to $OUTPUT_FILE."
