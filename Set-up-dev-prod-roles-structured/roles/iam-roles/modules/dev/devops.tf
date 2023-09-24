resource "aws_iam_role" "devops" {
  name = var.devops_role

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

resource "aws_iam_policy" "full_permission" {
  name        = var.devops_policy
  
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "*",
            "Resource": "*"
        }
    ]
}

EOF
}




resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.devops.name
  policy_arn = aws_iam_policy.full_permission.arn
}


