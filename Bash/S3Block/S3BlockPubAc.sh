#!/bin/bash

# List of S3 bucket names
buckets=(

)

# Count of buckets
bucket_count=0

# Iterate over each bucket in the list
for bucket in "${buckets[@]}"; do
    echo "Blocking public access for bucket: $bucket"
    
    # Block all public access for the bucket
    aws s3api put-public-access-block \
        --bucket "$bucket" \
        --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    
    if [ $? -eq 0 ]; then
        echo "Public access blocked successfully for bucket: $bucket"
        ((bucket_count++))
    else
        echo "Failed to block public access for bucket: $bucket"
    fi
done

echo "Script execution completed."
echo "Total number of buckets processed: $bucket_count"
