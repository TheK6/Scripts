#!/bin/bash

# Input file containing the list of bucket names
BUCKET_FILE="buckets.csv"
# Output file to save the results
OUTPUT_FILE="bucket_check_results.csv"

# Check if the input file exists
if [[ ! -f "$BUCKET_FILE" ]]; then
  echo "Bucket file not found: $BUCKET_FILE"
  exit 1
fi

# Write the header row to the output file
echo -e "Bucket Name\tExists" > "$OUTPUT_FILE"

# Loop through each bucket name in the file
while IFS= read -r bucket; do
  # Check if the bucket name is empty (skip empty lines)
  if [[ -z "$bucket" ]]; then
    continue
  fi

  # Check if the bucket exists using the AWS CLI
  if aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
    exists="True"
  else
    exists="False"
  fi

  # Append the result to the output file
  echo -e "$bucket\t$exists" >> "$OUTPUT_FILE"
done < "$BUCKET_FILE"

echo "Results written to $OUTPUT_FILE"

