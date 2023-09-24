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

# deny access to secret 
resource "aws_iam_policy" "deny" {
  name        = var.devops_policy
  

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Stmt1671647328945",
            "Action": "secretsmanager:*",
            "Effect": "Deny",
            "Resource": "*"
        }
    ]
}
EOF
}




resource "aws_iam_role_policy_attachment" "test-attach-dev" {
  role       = aws_iam_role.devops.name
  policy_arn = aws_iam_policy.deny.arn
}


# full ec2 access
data "aws_iam_policy" "AmazonEC2FullAccess" {
  arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "test-attach-dev-2" {
  role       = aws_iam_role.devops.name
  policy_arn = "${data.aws_iam_policy.AmazonEC2FullAccess.arn}"
}

# read access to all services
data "aws_iam_policy" "ReadOnlyAccess" {
  arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "read-svc" {
  role       = aws_iam_role.devops.name
  policy_arn = "${data.aws_iam_policy.ReadOnlyAccess.arn}"
}