#!/bin/bash

# Define the SSM document YAML file
SSM_DOCUMENT_YAML="docContent.yaml"

# Name for the SSM document (change as needed)
SSM_DOCUMENT_NAME="ARM-GroupPassword"

# CSV file to log created documents
CSV_FILE="doc_created.csv"

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

      # Create the SSM document in the current region and capture its document version
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
        echo "SSM document $SSM_DOCUMENT_NAME created successfully in region $REGION with document version $DOCUMENT_OUTPUT."
      else
        echo "Error creating SSM document in region $REGION."
      fi
    else
      echo "SSM document $SSM_DOCUMENT_NAME already exists in $REGION. Checking for changes..."

      # Get the content of the existing document
      EXISTING_DOCUMENT_CONTENT=$(aws ssm get-document \
        --region "$REGION" \
        --name "$SSM_DOCUMENT_NAME" \
        --query "Content" \
        --output text)

      # Get the new document content
      NEW_DOCUMENT_CONTENT=$(cat "$SSM_DOCUMENT_YAML")

      if [ "$EXISTING_DOCUMENT_CONTENT" == "$NEW_DOCUMENT_CONTENT" ]; then
        echo "No changes detected in the document content for $REGION. Skipping update."
        DOCUMENT_OUTPUT=$(aws ssm describe-document --region "$REGION" --name "$SSM_DOCUMENT_NAME" --query "Document.DocumentVersion" --output text)
      else
        # Get the latest document version
        LATEST_VERSION=$(aws ssm describe-document --region "$REGION" --name "$SSM_DOCUMENT_NAME" --query "Document.LatestVersion" --output text)

        # Increment the document version by 1
        NEXT_VERSION=$((LATEST_VERSION + 1))

        echo "Updating SSM document to version $NEXT_VERSION..."

        # Update the existing SSM document using the $LATEST version
        aws ssm update-document-default-version \
          --region "$REGION" \
          --name "$SSM_DOCUMENT_NAME" \
          --content "file://$SSM_DOCUMENT_YAML" \
          --document-format "YAML" \
          --target-type "/AWS::EC2::Instance" \
          --document-version "$LATEST_VERSION"

        if [ $? -eq 0 ]; then
          echo "SSM document $SSM_DOCUMENT_NAME updated successfully in region $REGION."

          # Set the next version as the document version
          DOCUMENT_OUTPUT=$NEXT_VERSION
        else
          echo "Error updating SSM document in region $REGION."
        fi
      fi
    fi

    # Only update the default version if a valid document version is found
    if [[ "$DOCUMENT_OUTPUT" =~ ^[1-9][0-9]*$ ]]; then
      # Set the latest document version as the default version (using numeric version)
      DEFAULT_VERSION_OUTPUT=$(aws ssm update-document-default-version \
        --region "$REGION" \
        --name "$SSM_DOCUMENT_NAME" \
        --document-version "$DOCUMENT_OUTPUT")

      if [ $? -eq 0 ]; then
        echo "SSM document $SSM_DOCUMENT_NAME in region $REGION is now using document version $DOCUMENT_OUTPUT as the default."
      else
        echo "Error setting the default version of SSM document in region $REGION."
      fi
    else
      echo "No valid document version found for $SSM_DOCUMENT_NAME in region $REGION."
    fi

    # Log the region and instance count into the CSV file
    echo "$REGION,$INSTANCE_COUNT" >> "$CSV_FILE"
    
  else
    echo "No instances found in region $REGION. Skipping SSM document creation."
  fi

  echo "---------------------------------------------"
done

echo "Script completed."
echo "Document creation log is available in $CSV_FILE."
