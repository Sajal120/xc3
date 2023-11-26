# Creating archive files

locals {
  generate_report_lambda_archive = {
    generate_usage_report = {
      source_file = "../src/generate_report/generate_cost_usage_report.py"
      output_path = "${path.module}/generate_usage_report.zip"
    }
  }
}

data "archive_file" "generate_usage_report_lambda_src" {
  for_each    = local.generate_report_lambda_archive
  type        = "zip"
  source_file = each.value.source_file
  output_path = each.value.output_path
}

# Creating Inline policy
resource "aws_iam_role_policy" "GenerateReport" {
  name = "${var.namespace}-lambda-inline-policy"
  role = aws_iam_role.GenerateReportRole.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "CostExplorerAccess"
        Action = [
          "aws-portal:ViewBilling",
          "ce:GetCostAndUsage",
          "ce:CreateCostAndUsageReport",
          "ce:DescribeReportDefinitions",
          "ce:ModifyReportDefinition",
          "ce:DeleteReportDefinition",
          "ec2:DescribeInstances",
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AttachNetworkInterface"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        "Effect" : "Allow",
        "Action" : "cur:PutReportDefinition",
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:GetBucketAcl",
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        "Resource" : [
          "arn:aws:s3:::${var.s3_xc3_bucket.id}",
          "arn:aws:s3:::${var.s3_xc3_bucket.id}/*"
        ]
      }
    ]
  })
}

# Creating IAM Role for Lambda functions
resource "aws_iam_role" "GenerateReportRole" {
  name = "${var.namespace}-generate-usage-report"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "generateusagereport"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  managed_policy_arns = []
  tags                = merge(local.tags, tomap({ "Name" = "${var.namespace}-Generate-Usage-Report-Role" }))
}

resource "aws_lambda_function" "GenerateReport" {
  #ts:skip=AWS.LambdaFunction.LM.MEIDUM.0063 We are aware of the risk and choose to skip this rule
  #ts:skip=AWS.LambdaFunction.Logging.0470 We are aware of the risk and choose to skip this rule
  #ts:skip=AWS.LambdaFunction.EncryptionandKeyManagement.0471 We are aware of the risk and choose to skip this rule
  function_name = "${var.namespace}-generate_cost_usage_report"
  role          = aws_iam_role.GenerateReportRole.arn
  runtime       = "python3.9"
  handler       = "generate_cost_usage_report.lambda_handler"
  filename      = values(data.archive_file.generate_usage_report_lambda_src)[0].output_path
  environment {
    variables = {
      bucket_name   = var.s3_xc3_bucket.bucket
      report_prefix = var.s3_prefixes.report
    }
  }
  memory_size = var.memory_size
  timeout     = var.timeout
  layers      = [var.prometheus_layer]

  vpc_config {
    subnet_ids         = [var.subnet_id[0]]
    security_group_ids = [var.security_group_id]
  }

  tags = merge(local.tags, tomap({ "Name" = "${var.namespace}-generate_report_function" }))
}

resource "terraform_data" "delete_generate_report_zip_files" {
  for_each         = local.generate_report_lambda_archive
  triggers_replace = ["arn:aws:lambda:${var.region}:${var.account_id}:function:${each.key}"]
  depends_on       = [aws_lambda_function.GenerateReport]

  provisioner "local-exec" {
    command = "rm -rf ${each.value.output_path}"
  }
}
