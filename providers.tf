provider "aws" {
  region = "ap-south-1" # Choose your desired AWS region (e.g., "ap-south-1" for Mumbai)
  # You can also use credentials from ~/.aws/credentials or environment variables.
  # Terraform will automatically pick up AWS credentials configured via `aws configure`
  # or environment variables like AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY.
}