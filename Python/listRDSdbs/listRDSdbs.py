import boto3
import csv
from datetime import datetime

# Initialize clients
sts_client = boto3.client("sts")
ec2_client = boto3.client("ec2")

# Get the AWS Account ID
account_id = sts_client.get_caller_identity()["Account"]

# Define the output CSV file name with account name
OUTPUT_FILE = f"{account_id}_rds_resources.csv"

# Get all available regions
regions = [region["RegionName"] for region in ec2_client.describe_regions()["Regions"]]

# Define the fields to extract
fields = ["ResourceType", "Region", "Identifier", "Status", "Role", "Engine", "Size", "MultiAZ", "CreationDate"]

# Open the CSV file to write
with open(OUTPUT_FILE, mode="w", newline="") as csvfile:
    writer = csv.writer(csvfile)
    writer.writerow(fields)  # Write header row
    
    # Iterate through each region to list RDS instances and clusters
    for region in regions:
        print(f"Checking RDS resources in region: {region}")
        rds_client = boto3.client("rds", region_name=region)
        
        # Retrieve and write RDS instances
        try:
            response = rds_client.describe_db_instances()
            db_instances = response["DBInstances"]
            
            for db_instance in db_instances:
                # Extract relevant fields for each RDS instance
                resource_type = "Instance"
                identifier = db_instance["DBInstanceIdentifier"]
                status = db_instance["DBInstanceStatus"]
                role = db_instance.get("ReadReplicaSourceDBInstanceIdentifier", "Primary")
                engine = db_instance["Engine"]
                size = db_instance["DBInstanceClass"]
                multi_az = db_instance["MultiAZ"]
                creation_date = db_instance["InstanceCreateTime"].strftime("%Y-%m-%d %H:%M:%S")
                
                # Write row to CSV file
                writer.writerow([resource_type, region, identifier, status, role, engine, size, multi_az, creation_date])

        except Exception as e:
            print(f"Could not retrieve RDS instances in region {region}: {e}")

        # Retrieve and write RDS clusters
        try:
            response = rds_client.describe_db_clusters()
            db_clusters = response["DBClusters"]
            
            for db_cluster in db_clusters:
                # Extract relevant fields for each RDS cluster
                resource_type = "Cluster"
                identifier = db_cluster["DBClusterIdentifier"]
                status = db_cluster["Status"]
                role = "Primary" if not db_cluster.get("ReadReplicaIdentifiers") else "Replica"
                engine = db_cluster["Engine"]
                size = "N/A"  # Cluster has instances with their own sizes
                multi_az = db_cluster.get("MultiAZ", "Unknown")
                creation_date = db_cluster["ClusterCreateTime"].strftime("%Y-%m-%d %H:%M:%S")
                
                # Write row to CSV file
                writer.writerow([resource_type, region, identifier, status, role, engine, size, multi_az, creation_date])

        except Exception as e:
            print(f"Could not retrieve RDS clusters in region {region}: {e}")

print(f"RDS resource information has been written to {OUTPUT_FILE}")
