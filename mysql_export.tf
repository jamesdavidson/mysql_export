resource "aws_s3_bucket" "backups" {
  bucket = "backups-${var.account_id}"
  region = "${var.region}"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = "arn:aws:kms:${var.region}:${var.account_id}:alias/aws/s3"
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

resource "aws_lambda_function" "mysql_export" {
  function_name    = "mysql_export"
  description      = "Exports data from a MySQL database and copies to S3."
  role             = "${aws_iam_role.mysql_export.arn}"
  filename         = "./build/release.zip"
  source_code_hash = "${base64sha256(file("./build/release.zip"))}"
  runtime          = "python3.6"
  handler          = "index.handler"
  timeout          = 360
  memory_size      = 128

  environment {
    variables = {
      # DEBUG  = "yes"
      BUCKET = "backups-${var.account_id}"
    }
  }

  # vpc_config {
  #   subnet_ids         = "${var.app_server_subnets}"
  #   security_group_ids = "${var.app_server_groups}"
  # }
}

resource "aws_iam_role" "mysql_export" {
  name = "mysql_export"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "mysql_export" {
  role       = "${aws_iam_role.mysql_export.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "mysql_export_extra" {
  role       = "${aws_iam_role.mysql_export.name}"
  policy_arn = "${aws_iam_policy.mysql_export_extra.arn}"
}

resource "aws_iam_policy" "mysql_export_extra" {
  name = "mysql_export"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameter"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject"
            ],
            "Resource": "${aws_s3_bucket.backups.arn}/*"
        }
    ]
}
EOF
}

resource "aws_cloudwatch_metric_alarm" "mysql_export_errors" {
  alarm_name          = "${var.environment}-${aws_lambda_function.mysql_export.id}-Errors"
  alarm_description   = "MySQL export failed in ${var.environment} account."
  datapoints_to_alarm = "1"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  threshold           = "0"
  comparison_operator = "GreaterThanThreshold"
  period              = "60"
  statistic           = "Sum"
  treat_missing_data  = "missing"
  namespace           = "AWS/Lambda"

  dimensions {
    FunctionName = "${aws_lambda_function.mysql_export.id}"
    Resource     = "${aws_lambda_function.mysql_export.id}"
  }

  # alarm_actions = [
  #   "${aws_sns_topic.alerts.arn}",
  # ]
}
