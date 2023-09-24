terraform {
  backend "s3" {
    bucket = "terraform-backend-statefile-centoes"
    key    = "./alarm.tfstate"
    region = "us-east-1"
  }
}
