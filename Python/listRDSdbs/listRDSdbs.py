import boto3
import csv

# Initialize clients
sts_client = boto3.client("sts")
ec2_client = boto3.client("ec2")

# Get the AWS Account ID
account_id = sts_client.get_caller_identity()["Account"]

# # Try to get the account name using Organizations
# try:
#     org_client = boto3.client("organizations")
#     account_name = org_client.describe_account(AccountId=account_id)["Account"]["Name"]
# except Exception as e:
#     print(f"Could not retrieve account name. Using account ID as name: {e}")
#     account_name = account_id

# Define the output CSV file name with account name
OUTPUT_FILE = f"{account_id}_rds_resources.csv"

# Get all available regions
regions = [region["RegionName"] for region in ec2_client.describe_regions()["Regions"]]

# Define the fields to extract
fields = ["ResourceType", "Region", "Identifier", "Status", "Role", "Engine", "Size", "MultiAZ"]

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
                
                # Write row to CSV file
                writer.writerow([ region, identifier, resource_type, role, status, engine, size, multi_az])

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
                
                # Write row to CSV file
                writer.writerow([ region, identifier, resource_type, role, status, engine, size, multi_az])

        except Exception as e:
            print(f"Could not retrieve RDS clusters in region {region}: {e}")

print(f"RDS resource information has been written to {OUTPUT_FILE}")
