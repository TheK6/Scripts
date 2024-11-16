import boto3
import os

def delete_objects_in_batch(bucket_name, delete_keys):
    s3 = boto3.client('s3')
    batch_size = 1000
    for i in range(0, len(delete_keys), batch_size):
        batch = delete_keys[i:i + batch_size]
        try:
            s3.delete_objects(
                Bucket=bucket_name,
                Delete={'Objects': batch}
            )
        except Exception as e:
            print(f"Error during batch delete: {e}")

def collect_objects_for_deletion(bucket, prefix):
    delete_keys = []

    # Coletar versões de objetos e delete markers
    versions_to_delete = bucket.object_versions.filter(Prefix=prefix)
    for version in versions_to_delete:
        delete_keys.append({'Key': version.object_key, 'VersionId': version.id})

    # Coletar objetos mais recentes
    objects_to_delete = bucket.objects.filter(Prefix=prefix)
    for obj in objects_to_delete:
        delete_keys.append({'Key': obj.key})

    return delete_keys

def delete_objects_from_file(bucket_name, file_path):
    s3 = boto3.resource('s3')
    bucket = s3.Bucket(bucket_name)

    if not os.path.isfile(file_path):
        print(f"O arquivo {file_path} não existe.")
        return

    with open(file_path, 'r') as file:
        prefixes_to_delete = [line.strip() for line in file if line.strip()]

    if not prefixes_to_delete:
        print("O arquivo de texto está vazio ou não contém prefixos válidos.")
        return

    for prefix in prefixes_to_delete:
        delete_keys = collect_objects_for_deletion(bucket, prefix)

        if delete_keys:
            while delete_keys:
                delete_objects_in_batch(bucket_name, delete_keys)
                delete_keys = collect_objects_for_deletion(bucket, prefix)
            
            print(f"Successfully deleted all objects for prefix: {prefix}")
        else:
            print(f"No objects found for prefix: {prefix}")

if __name__ == "__main__":
    bucket_name = 'lennarcorporation-140'  # Substitua pelo nome do seu bucket
    file_path = 'files.txt'  # Substitua pelo caminho do arquivo de texto
    
    delete_objects_from_file(bucket_name, file_path)