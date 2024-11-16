#!/bin/bash

# Input file containing the event patterns and other configurations
INPUT_FILE="alarm_event_patterns.txt"

# Replace these placeholders with actual values
ACCOUNT_ID="261140574810"   # Replace with your AWS account ID
SSM_DOCUMENT_NAME="arm-thread-dumps-dev"  # Replace with your function name
EVENTBRIDGE_RULE_ROLE="arn:aws:iam::261140574810:role/Eventbridge_SSM_Permissions"

# Iterate over each event pattern in the file
while IFS= read -r line; do
    # Check if the line indicates alarm creation with region info
    if [[ $line == "Alarm created:"* ]]; then
        # Extract alarm name
        ALARM_NAME=$(echo "$line" | grep -o 'CPUTheadDumpTest_[^ ]*')
        INSTANCE_ID=$(echo "$ALARM_NAME" | grep -o 'i-[0-9a-fA-F]\+')
 
        # Extract region from the line (assuming it’s the last word in the line)
        REGION=$(echo "$line" | grep -oP '(?<=region )[a-zA-Z0-9-]+')

        # Validate extracted details
        if [[ -z "$ALARM_NAME" || -z "$INSTANCE_ID" || -z "$REGION" ]]; then
            echo "Could not parse alarm details from line: $line"
            continue
        fi

        # Construct rule name using the alarm name
        RULE_NAME="${ALARM_NAME}_rule"

        echo "Creating EventBridge rule '$RULE_NAME' in region $REGION with target for instance $INSTANCE_ID..."

        # Read the entire event pattern (multi-line JSON) until the closing bracket
        EVENT_PATTERN=""
        while IFS= read -r pattern_line; do
            EVENT_PATTERN+="$pattern_line"
            # Break when reaching the closing bracket of the event pattern
            if [[ "$pattern_line" == "}" ]]; then
                break
            fi
        done

        # # Set the target ARN using ACCOUNT_ID, FUNCTION_NAME, and INSTANCE_ID
        # TARGET_ARN="arn:aws:lambda:$REGION:$ACCOUNT_ID:function:$FUNCTION_NAME"_"$INSTANCE_ID"

        # Create the EventBridge rule in the extracted region
        aws events put-rule \
            --name "$RULE_NAME" \
            --event-pattern "$EVENT_PATTERN" \
            --region "$REGION" \
            --description "Event rule for alarm $ALARM_NAME targeting instance $INSTANCE_ID"

        # Attach the target to the rule in the specified region
        aws events put-targets \
            --rule "$RULE_NAME" \
            --targets "Id"="1","Arn"="arn:aws:ssm:$REGION:$ACCOUNT_ID:document/$SSM_DOCUMENT_NAME","Input"="{\'InstanceIds\':[\'$INSTANCE_ID\']}" \
            --region "$REGION"

        echo "Created EventBridge rule '$RULE_NAME' in region $REGION with target for instance $INSTANCE_ID."
    fi
done < "$INPUT_FILE"
