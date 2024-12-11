#!/bin/bash

# Define the SSM document YAML file
SSM_DOCUMENT_YAML="docContent.yaml"

# Name for the SSM document
SSM_DOCUMENT_NAME="ARM-GroupPassword"

# CSV file to log created documents
CSV_FILE="doc_created.csv"

# Ensure the SSM document YAML exists
if [ ! -f "$SSM_DOCUMENT_YAML" ]; then
  echo "Error: $SSM_DOCUMENT_YAML not found. Please ensure the file exists in the current directory."
  exit 1
fi

# Create or clear the CSV file and add headers
echo "Region,InstanceCount" > "$CSV_FILE"

# Get all AWS regions
REGIONS=$(aws ec2 describe-regions --query "Regions[].RegionName" --output text)

# Loop through each region
for REGION in $REGIONS; do
  echo "Checking region: $REGION"
  
  # Check if there are any running EC2 instances in the region
  INSTANCE_COUNT=$(aws ec2 describe-instances --region "$REGION" --query "Reservations[*].Instances[*].InstanceId" --output text | wc -w)

  if [ "$INSTANCE_COUNT" -gt 0 ]; then
    echo "Found $INSTANCE_COUNT instances in $REGION."

    # Check if SSM document already exists
    DOCUMENT_EXISTS=$(aws ssm list-documents --region "$REGION" --query "DocumentIdentifiers[?Name=='$SSM_DOCUMENT_NAME'].Name" --output text)

    if [ -z "$DOCUMENT_EXISTS" ]; then
      echo "Creating new SSM document in $REGION..."
      DOCUMENT_OUTPUT=$(aws ssm create-document \
        --region "$REGION" \
        --name "$SSM_DOCUMENT_NAME" \
        --document-type "Command" \
        --content "file://$SSM_DOCUMENT_YAML" \
        --document-format "YAML" \
        --target-type "/AWS::EC2::Instance" \
        --query "DocumentDescription.DocumentVersion" \
        --output text)

      if [ $? -eq 0 ]; then
        echo "SSM document $SSM_DOCUMENT_NAME created successfully in region $REGION."
      else
        echo "Error creating SSM document in region $REGION."
      fi
    else
      echo "SSM document $SSM_DOCUMENT_NAME already exists in $REGION. Checking for changes..."

      EXISTING_DOCUMENT_CONTENT=$(aws ssm get-document \
        --region "$REGION" \
        --name "$SSM_DOCUMENT_NAME" \
        --query "Content" \
        --output text)

      if diff <(echo "$EXISTING_DOCUMENT_CONTENT") "$SSM_DOCUMENT_YAML" > /dev/null; then
        echo "No changes detected. Skipping update."
      else
        echo "Updating SSM document in $REGION..."
        aws ssm update-document \
          --region "$REGION" \
          --name "$SSM_DOCUMENT_NAME" \
          --content "file://$SSM_DOCUMENT_YAML" \
          --document-format "YAML" \
          --target-type "/AWS::EC2::Instance" \
          --document-version "\$LATEST"

        if [ $? -eq 0 ]; then
          echo "SSM document $SSM_DOCUMENT_NAME updated successfully in region $REGION."
        else
          echo "Error updating SSM document in $REGION."
        fi
      fi
    fi

    # Set the latest document version as default
    LATEST_VERSION=$(aws ssm describe-document \
      --region "$REGION" \
      --name "$SSM_DOCUMENT_NAME" \
      --query "Document.LatestVersion" \
      --output text)

    aws ssm update-document-default-version \
      --region "$REGION" \
      --name "$SSM_DOCUMENT_NAME" \
      --document-version "$LATEST_VERSION"

    if [ $? -eq 0 ]; then
      echo "Default version of $SSM_DOCUMENT_NAME set to $LATEST_VERSION in region $REGION."
    else
      echo "Error setting default version for $SSM_DOCUMENT_NAME in region $REGION."
    fi

    # Log the region and instance count
    echo "$REGION,$INSTANCE_COUNT" >> "$CSV_FILE"
  else
    echo "No instances found in region $REGION. Skipping."
  fi

  echo "---------------------------------------------"
done

echo "Script completed."
echo "Document creation log is available in $CSV_FILE."
