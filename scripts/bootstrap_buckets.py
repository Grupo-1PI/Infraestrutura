from __future__ import annotations

import argparse

import boto3
from botocore.exceptions import ClientError


def ensure_private_bucket(s3, bucket: str, region: str) -> None:
    try:
        create_args = {"Bucket": bucket}
        if region != "us-east-1":
            create_args["CreateBucketConfiguration"] = {
                "LocationConstraint": region
            }
        s3.create_bucket(**create_args)
        print(f"Bucket criado: {bucket}", flush=True)
    except ClientError as error:
        code = error.response.get("Error", {}).get("Code")
        if code != "BucketAlreadyOwnedByYou":
            raise
        print(f"Bucket existente, será reutilizado: {bucket}", flush=True)

    s3.put_public_access_block(
        Bucket=bucket,
        PublicAccessBlockConfiguration={
            "BlockPublicAcls": True,
            "IgnorePublicAcls": True,
            "BlockPublicPolicy": True,
            "RestrictPublicBuckets": True,
        },
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Cria ou reutiliza os buckets do data lake e os mantém privados."
    )
    parser.add_argument("--region", required=True)
    parser.add_argument("--bronze-bucket", required=True)
    parser.add_argument("--silver-bucket", required=True)
    args = parser.parse_args()

    s3 = boto3.client("s3", region_name=args.region)
    ensure_private_bucket(s3, args.bronze_bucket, args.region)
    ensure_private_bucket(s3, args.silver_bucket, args.region)


if __name__ == "__main__":
    main()
