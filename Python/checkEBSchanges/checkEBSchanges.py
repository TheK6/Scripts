import boto3
import csv
from datetime import datetime
import json
import time

# Output files
output_csv_file = "volume_modifications.csv"
raw_events_file = "modify_volume_events.txt"  # New file to store raw events

# Date range for filtering (update as needed)
start_date = "2024-11-28T00:00:00Z"  # Start of date range (ISO 8601 format)
end_date = "2024-11-30T23:59:59Z"    # End of date range (ISO 8601 format)

# Convert date range to datetime objects
start_date_dt = datetime.strptime(start_date, "%Y-%m-%dT%H:%M:%SZ")
end_date_dt = datetime.strptime(end_date, "%Y-%m-%dT%H:%M:%SZ")

# AWS Regions (update or fetch dynamically)
specific_regions = ["us-east-1"]
aws_regions = specific_regions if specific_regions else boto3.Session().get_available_regions("ec2")


# def parse_modify_volume_event(event):
#     """Extract volume modification details from a ModifyVolume event."""
#     try:
#         volume_id = event["requestParameters"]["ModifyVolumeRequest"]["VolumeId"]
#         original_size = event["responseElements"]["ModifyVolumeResponse"]["volumeModification"]["originalSize"]
#         target_size = event["responseElements"]["ModifyVolumeResponse"]["volumeModification"]["targetSize"]
#         region = event["awsRegion"]
#         event_time = event["eventTime"]
#         return {
#             "Volume ID": volume_id,
#             "Original Size (GiB)": original_size,
#             "Target Size (GiB)": target_size,
#             "Region": region,
#             "Event Time": event_time
#         }
#     except KeyError as e:
#         print(f"KeyError while parsing event: {e}")
#         return None


# def consolidate_volume_changes(results):
#     """Consolidate all size changes for each volume into a single entry."""
#     consolidated = {}
#     for entry in results:
#         volume_id = entry["Volume ID"]
#         size_change = entry["Target Size (GiB)"] - entry["Original Size (GiB)"]

#         if volume_id not in consolidated:
#             consolidated[volume_id] = {
#                 "Volume ID": volume_id,
#                 "Region": entry["Region"],
#                 "Total Size Increase (GiB)": size_change,
#                 "Modification Count": 1,
#                 "Event Times": [entry["Event Time"]]
#             }
#         else:
#             consolidated[volume_id]["Total Size Increase (GiB)"] += size_change
#             consolidated[volume_id]["Modification Count"] += 1
#             consolidated[volume_id]["Event Times"].append(entry["Event Time"])
    
#     return [
#         {
#             "Volume ID": v["Volume ID"],
#             "Region": v["Region"],
#             "Total Size Increase (GiB)": v["Total Size Increase (GiB)"],
#             "Modification Count": v["Modification Count"],
#             "Event Times": ", ".join(v["Event Times"])
#         }
#         for v in consolidated.values()
#     ]


def fetch_modify_volume_events_for_region(region):
    """Fetch ModifyVolume events for a specific region."""
    cloudtrail_client = boto3.client("cloudtrail", region_name=region)
    next_token = None
    results = []

    print(f"Fetching ModifyVolume events for region: {region}...")
    retries = 0
    max_retries = 5

    while True:
        try:
            if next_token:
                response = cloudtrail_client.lookup_events(
                    StartTime=start_date_dt,
                    EndTime=end_date_dt,
                    NextToken=next_token
                )
            else:
                response = cloudtrail_client.lookup_events(
                    StartTime=start_date_dt,
                    EndTime=end_date_dt
                )
            
            # Process each event
            for event in response["Events"]:
                if event["EventName"] == "ModifyVolume":
                    try:
                        cloudtrail_event = json.loads(event["CloudTrailEvent"])
                        
                        # Write raw event to file
                        with open(raw_events_file, "a") as file:
                            file.write(json.dumps(cloudtrail_event) + "\n")
                        
                        # Parse and store structured data
                        modification_details = parse_modify_volume_event(cloudtrail_event)
                        if modification_details:
                            results.append(modification_details)
                    except json.JSONDecodeError as e:
                        print(f"JSONDecodeError in region {region}: {e}")
            
            next_token = response.get("NextToken")
            if not next_token:
                break
        
        except boto3.exceptions.Boto3Error as e:
            print(f"Error while fetching events for region {region}: {e}")
            retries += 1
            if retries > max_retries:
                print(f"Exceeded max retries for region {region}. Skipping.")
                break
            time.sleep(2 ** retries)  # Exponential backoff

        except Exception as e:
            print(f"Unexpected error while fetching events for region {region}: {e}")
            break
    
    return results


# def write_to_csv(filename, data):
#     """Write data to a CSV file."""
#     try:
#         with open(filename, "w", newline="") as file:
#             csv_writer = csv.DictWriter(file, fieldnames=[
#                 "Volume ID",
#                 "Region",
#                 "Total Size Increase (GiB)",
#                 "Modification Count",
#                 "Event Times"
#             ])
#             csv_writer.writeheader()
#             csv_writer.writerows(data)
#         print(f"Output successfully written to {filename}.")
#     except Exception as e:
#         print(f"Error writing to CSV: {e}")


def main():
    print("Starting script...")

    # Clear the raw events file before writing
    with open(raw_events_file, "w") as file:
        file.write("")  # Empty the file

    all_results = []

    # Process each region
    for region in aws_regions:
        print(f"Processing region: {region}")
        region_results = fetch_modify_volume_events_for_region(region)
        all_results.extend(region_results)

    if not all_results:
        print("No events found in the specified date range.")
        return

    # Consolidate results
    print("Consolidating volume changes...")
    consolidated_results = consolidate_volume_changes(all_results)

    # Write to CSV
    print(f"Writing consolidated results to {output_csv_file}...")
    write_to_csv(output_csv_file, consolidated_results)


if __name__ == "__main__":
    main()
