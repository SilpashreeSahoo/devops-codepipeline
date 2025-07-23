# A. Random String for Bucket Name (to ensure uniqueness)
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
  numeric = true
}

# B. S3 Artifact Bucket
resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket = "${var.s3_artifact_bucket_name}-${random_string.bucket_suffix.id}"

  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "codepipeline_artifacts_versioning" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# C. IAM Roles and Policies (for CodePipeline, CodeBuild, CodeDeploy)

# CodePipeline IAM Role
resource "aws_iam_role" "codepipeline_role" {
  name = "${var.project_name}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      },
    ]
  })
}

variable "us-east-1" {
  default = ""
}
resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${var.project_name}-codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:GetBucketVersioning",
          "s3:PutObjectAcl",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.codepipeline_artifacts.arn,
          "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
        ]
        Effect = "Allow"
      },
      {
        Action = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds"
        ]
        Resource = aws_codebuild_project.app_build.arn
        Effect = "Allow"
      },
      {
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplication",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision"
        ]
        Resource = [
           aws_codedeploy_application.app.arn,
           "${aws_codedeploy_application.app.arn}/*"
        ]
        Effect = "Allow"
      },
      {
        Action = "codestar-connections:UseConnection"
        Resource = "arn:aws:codeconnections:ap-south-1:928096314836:connection/2e23edaa-5748-43a0-8275-7aeac0a44ecf" # REPLACE with actual Connection ARN and your Account ID
        Effect = "Allow"
      }
    ]
  })
}

# CodeBuild IAM Role
resource "aws_iam_role" "codebuild_role" {
  name = "${var.project_name}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      },
    ]
  })
}

variable "ap-south-1" {
  default = ""
}
resource "aws_iam_role_policy" "codebuild_policy" {
  name = "${var.project_name}-codebuild-policy"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.ap-south-1}:928096314836:log-group:/aws/codebuild/${aws_codebuild_project.app_build.name}:*" # Refined
        Effect = "Allow"
      },
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.codepipeline_artifacts.arn,
          "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
        ]
        Effect = "Allow"
      },
    ]
  })
}

# CodeDeploy IAM Role (for EC2 instances/Lambda - if deploying to EC2)
resource "aws_iam_role" "codedeploy_ec2_role" {
  name = "${var.project_name}-codedeploy-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "codedeploy_ec2_instance_profile" {
  name = "${var.project_name}-codedeploy-ec2-instance-profile"
  role = aws_iam_role.codedeploy_ec2_role.name
}

resource "aws_iam_role_policy_attachment" "codedeploy_ec2_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
  role       = aws_iam_role.codedeploy_ec2_role.name
}

# D. AWS CodeBuild Project
resource "aws_codebuild_project" "app_build" {
  name          = "${var.project_name}-app-build"
  description   = "Build project for the application"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type            = "CODEPIPELINE"
    buildspec       = var.buildspec_path
  }

  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

# E. AWS CodeDeploy Application and Deployment Group (for EC2)
resource "aws_codedeploy_application" "app" {
  name = var.codedeploy_application_name
}

resource "aws_codedeploy_deployment_group" "app_group" {
  application_name      = aws_codedeploy_application.app.name
  deployment_group_name = var.codedeploy_deployment_group_name
  service_role_arn      = aws_iam_role.codepipeline_role.arn

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Environment"
      type  = "KEY_AND_VALUE"
      value = "Dev" # Replace with a tag on your target EC2 instances
    }
    ec2_tag_filter {
      key   = "App"
      type  = "KEY_AND_VALUE"
      value = "WebApp" # Another tag to identify your app servers
    }
  }

  deployment_style {
    deployment_option = "IN_PLACE"
    deployment_type   = "ONE_AT_A_TIME"
  }
}

# F. AWS CodePipeline
resource "aws_codepipeline" "app_pipeline" {
  name     = "${var.project_name}-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"

      configuration = {
        Owner                 = var.github_owner
        Repo                  = var.github_repo
        Branch                = var.github_branch
        PollForSourceChanges  = "false"
        ConnectionArn         = "arn:aws:codeconnections:ap-south-1:928096314836:connection/2e23edaa-5748-43a0-8275-7aeac0a44ecf" # <<< REPLACE THIS ENTIRE ARN
      }
      output_artifacts = ["SourceArtifact"]
    }
  }

  stage {
    name = "Build"
    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]
      configuration = {
        ProjectName = aws_codebuild_project.app_build.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name             = "Deploy"
      category         = "Deploy"
      owner            = "AWS"
      provider         = "CodeDeploy"
      version          = "1"
      input_artifacts  = ["BuildArtifact"]
      configuration = {
        ApplicationName     = aws_codedeploy_application.app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.app_group.name
      }
    }
  }

  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}