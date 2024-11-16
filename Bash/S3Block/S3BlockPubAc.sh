#!/bin/bash

# List of S3 bucket names
buckets=(
"codescan-prod-snapshot"
"codescanng-logs"
"cf-templates-kruoe3r1jkg0-us-east-1"
"codescanng-logs-elb-test-internal"
"elasticbeanstalk-us-east-1-567829905188"
"97ac76498cee49b8bebeb1e33f3efc23-logs"
"codescanng-cache-ohio"
"downloads.code-scan.com.logs"
"cf-templates-kruoe3r1jkg0-eu-central-1"
"muralitry11"
"downloads.code-scan.com.bucket"
"codescanng-cache-ap"
"codescanng-cache-eu"
"storequeryoutput"
"poc-preview-upload"
"codescanng-logs-elb-test"
"codepipeline-us-east-1-673025056697"
"hardening-scripts-codescan"
"codescanng-build"
"codescanng-cache"
"rackspace-db4ac94b8709a0357e43cdbe0725c3b77a4833ca"
"codescanawsdocumentation"
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
