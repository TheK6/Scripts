#!/bin/bash

bucket="wingate-28"
prefix="00D0K0000024T2yUAE/"
total_size=0
total_count=0

aws s3api list-objects-v2 --bucket $bucket --prefix $prefix --output json | jq -c '.Contents[]' | while read i; do
    size=$(echo $i | jq -r '.Size')
    key=$(echo $i | jq -r '.Key')
    total_size=$((total_size + size))
    total_count=$((total_count + 1))
    echo "File: $key | Size: $size bytes"
    echo "Total Size: $total_size bytes | Total Count: $total_count"
done

echo "Final Total Size: $total_size bytes"
echo "Final Total Count: $total_count"

