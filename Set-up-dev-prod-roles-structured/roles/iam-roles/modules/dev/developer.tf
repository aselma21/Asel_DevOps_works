resource "aws_iam_role" "developer" {
  name = var.developer_role
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${var.trusted_account_number}:root"
            },
            "Action": "sts:AssumeRole",
            "Condition": {}
        }
    ]
}
EOF
}

#  read permission for eks
resource "aws_iam_policy" "eks" {
  name        = var.developer_policy

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "eks:DescribeNodegroup",
                "eks:DescribeFargateProfile",
                "eks:ListTagsForResource",
                "eks:DescribeIdentityProviderConfig",
                "eks:DescribeUpdate",
                "eks:AccessKubernetesApi",
                "eks:DescribeCluster",
                "eks:DescribeAddonVersions",
                "eks:DescribeAddon"
            ],
            "Resource": "*"
        }
    ]
}

EOF
}


resource "aws_iam_role_policy_attachment" "eks_permission" {
  role       = aws_iam_role.developer.name
  policy_arn = aws_iam_policy.eks.arn
}


# for s3 bucket permission
data "aws_iam_policy" "AmazonS3FullAccess" {
  arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "s3-full" {
  role       = aws_iam_role.developer.name
  policy_arn = "${data.aws_iam_policy.AmazonS3FullAccess.arn}"
}


# for ec2 read permission
data "aws_iam_policy" "AmazonEC2ReadOnlyAccess" {
  arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "ec2-read" {
  role       = aws_iam_role.developer.name
  policy_arn = "${data.aws_iam_policy.AmazonEC2ReadOnlyAccess.arn}"
}

