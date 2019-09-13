# Uses default AWScli profile creds

# Provider and region
provider "aws" {
  region = "${var.aws_region}"
}

terraform {
  required_version = ">= 0.11.1"
}

# S3 resources

resource "random_id" "hash" {
  byte_length = 4
}

resource "aws_s3_bucket" "config" {
  bucket = "config-bucket-${random_id.hash.hex}"
}

# Config resources

resource "aws_config_configuration_recorder" "config" {
  name     = "Config"
  role_arn = "${aws_iam_role.config.arn}"
}

resource "aws_config_delivery_channel" "config" {
  name           = "example"
  s3_bucket_name = "${aws_s3_bucket.config.bucket}"
}

resource "aws_config_configuration_recorder_status" "config" {
  name       = "${aws_config_configuration_recorder.config.name}"
  is_enabled = true
  depends_on = ["aws_config_delivery_channel.config"]
}

# IAM dependencies

resource "aws_iam_role" "config" {
  name = "awsconfig-example"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "config.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "config-put" {
  name = "awsconfig-policy"
  role = "${aws_iam_role.config.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ConfigCTPerms",
      "Action": [ 
        "config:Put*",
        "cloudtrail:DescribeTrails",
        "cloudtrail:GetTrailStatus"
      ],
        "Effect": "Allow",
        "Resource": "*"
    },
    {
      "Sid": "S3Perms",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketAcl",
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
POLICY
}


# Managed Config Rules

resource "aws_config_config_rule" "Cloudtrail-enable" {
  name = "Cloudtrail-Enabled"
  description = "Terraform-managed: Checks whether AWS CloudTrail is enabled in your AWS account. Optionally, you can specify which S3 bucket, SNS topic, and Amazon CloudWatch Logs ARN to use."

  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENABLED"
  }
  
  depends_on = ["aws_config_configuration_recorder.config"]
}

resource "aws_config_config_rule" "s3-encryption" {
  name        = "S3-SSE-encrpytion-enabled"
  description = "Terraform-managed: Checks that your Amazon S3 bucket either has S3 default encryption enabled or that the S3 bucket policy explicitly denies put-object requests without server side encryption."

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }
  scope {
    compliance_resource_types = ["AWS::S3::Bucket"]
#    tag_key                   = "env"
#    tag_value                 = "prod"
  }
  depends_on = ["aws_config_configuration_recorder.config"]
}

