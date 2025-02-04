data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_iam_policy_document" "managed_ng_assume_role_policy" {
  statement {
    sid = "EKSWorkerAssumeRole"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = [local.ec2_principal]
    }
  }
}

data "aws_iam_policy_document" "s3_bucket_access" {
  statement {
    sid       = ""
    effect    = "Allow"
    resources = [
        "arn:aws:s3:::batch-artifact-repository-401305384268",
        "arn:aws:s3:::batch-artifact-repository-401305384268/*",
        "arn:aws:s3:::singlem-results-us-east-2",
        "arn:aws:s3:::singlem-results-us-east-2/*"
        ]
    actions = ["s3:*"]
  }
}

data "aws_iam_policy_document" "cluster_autoscaler" {
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "ec2:DescribeLaunchTemplateVersions"
    ]
  }
}

data "aws_iam_policy_document" "cwlogs" {
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
  }
}
