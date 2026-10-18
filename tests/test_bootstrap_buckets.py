import unittest
from unittest.mock import Mock

from botocore.exceptions import ClientError

from scripts.bootstrap_buckets import ensure_private_bucket


class EnsurePrivateBucketTests(unittest.TestCase):
    def test_creates_bucket_then_blocks_public_access(self) -> None:
        s3 = Mock()

        ensure_private_bucket(s3, "bronze-test", "us-east-1")

        s3.create_bucket.assert_called_once_with(Bucket="bronze-test")
        s3.put_public_access_block.assert_called_once_with(
            Bucket="bronze-test",
            PublicAccessBlockConfiguration={
                "BlockPublicAcls": True,
                "IgnorePublicAcls": True,
                "BlockPublicPolicy": True,
                "RestrictPublicBuckets": True,
            },
        )

    def test_reuses_bucket_owned_by_account(self) -> None:
        s3 = Mock()
        s3.create_bucket.side_effect = ClientError(
            {"Error": {"Code": "BucketAlreadyOwnedByYou"}},
            "CreateBucket",
        )

        ensure_private_bucket(s3, "bronze-test", "us-east-1")

        s3.put_public_access_block.assert_called_once()

    def test_propagates_bucket_creation_errors(self) -> None:
        s3 = Mock()
        s3.create_bucket.side_effect = ClientError(
            {"Error": {"Code": "AccessDenied"}},
            "CreateBucket",
        )

        with self.assertRaises(ClientError):
            ensure_private_bucket(s3, "bronze-test", "us-east-1")

        s3.put_public_access_block.assert_not_called()


if __name__ == "__main__":
    unittest.main()
