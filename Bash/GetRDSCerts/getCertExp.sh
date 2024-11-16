#!/bin/bash

# Number of days before expiration to check
DAYS_BEFORE_EXPIRATION=30

# Convert days to seconds (30 days = 2592000 seconds)
SECONDS_BEFORE_EXPIRATION=$((DAYS_BEFORE_EXPIRATION * 24 * 60 * 60))

# Get current date in ISO8601 format
CURRENT_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Calculate the threshold date
THRESHOLD_DATE=$(date -u -d "$CURRENT_DATE + $SECONDS_BEFORE_EXPIRATION seconds" +"%Y-%m-%dT%H:%M:%SZ")

# File to export results
OUTPUT_FILE="rds_expiring_certs.csv"

# Write header to CSV file
echo "Region,DBInstanceIdentifier,CACertificateIdentifier,CAExpirationDate,ExpiresWithinThreshold,AutoMinorVersionUpgrade" > "$OUTPUT_FILE"

# Function to check a region for RDS certificates
check_region() {
  local region=$1
  echo "Checking region: $region"

  # Describe RDS instances in the region
  aws rds describe-db-instances --region "$region" --query 'DBInstances[*].{DBInstanceIdentifier:DBInstanceIdentifier, CACertificateIdentifier:CACertificateIdentifier, Region:"'"$region"'"}' --output json |
  jq -c '.[]' |
  while IFS= read -r instance; do
    db_instance_identifier=$(echo "$instance" | jq -r '.DBInstanceIdentifier')
    ca_certificate_identifier=$(echo "$instance" | jq -r '.CACertificateIdentifier')
    
    # Describe the certificate to get its expiration date
    expiration_date=$(aws rds describe-certificates --region "$region" --certificate-identifier "$ca_certificate_identifier" --query 'Certificates[0].ValidTill' --output text)

    # Check if the expiration date is within the threshold
    expires_within_threshold="No"
    if [[ "$expiration_date" < "$THRESHOLD_DATE" ]]; then
      expires_within_threshold="Yes"
    fi

    # Get the AutoMinorVersionUpgrade status
    auto_minor_version_upgrade=$(aws rds describe-db-instances --region "$region" --db-instance-identifier "$db_instance_identifier" --query 'DBInstances[0].AutoMinorVersionUpgrade' --output text)

    echo "Region: $region, DBInstanceIdentifier: $db_instance_identifier, CACertificateIdentifier: $ca_certificate_identifier, CAExpirationDate: $expiration_date, ExpiresWithinThreshold: $expires_within_threshold, AutoMinorVersionUpgrade: $auto_minor_version_upgrade"
    echo "$region,$db_instance_identifier,$ca_certificate_identifier,$expiration_date,$expires_within_threshold,$auto_minor_version_upgrade" >> "$OUTPUT_FILE"
  done
}

# Get the list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text)

# Check each region for RDS certificates
for region in $regions; do
  check_region "$region"
done

echo "Check complete. Results saved to $OUTPUT_FILE."
