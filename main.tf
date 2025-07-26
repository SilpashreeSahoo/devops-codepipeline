# main.tf (FULL AND CORRECTED CONTENT)
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
        Resource = "*"
        Effect = "Allow"
      },
      {
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplication",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision",
          "codedeploy:RegisterApplication"
        ]
        Resource = "*"
        Effect = "Allow"
      },
      {
        Action = "codestar-connections:UseConnection"
        Resource = "arn:aws:codestar-connections:ap-south-1:928096314836:connection/2e23edaa-5748-43a0-8275-7aeac3a44ecf" # Your specific ARN
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
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${aws_codebuild_project.app_build.name}:*"
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

# Data sources for dynamic Account ID and Region in IAM policies
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


# CodeDeploy EC2 Instance Profile Role (for EC2 instances)
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

# --- DEDICATED CodeDeploy Service Role ---
resource "aws_iam_role" "codedeploy_service_role" {
  name = "${var.project_name}-codedeploy-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "codedeploy.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach the standard AWS CodeDeploy service policy to the dedicated role
resource "aws_iam_role_policy_attachment" "codedeploy_service_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.codedeploy_service_role.name
}
# --- END DEDICATED CodeDeploy Service Role ---


# D. AWS CodeBuild Project
resource "aws_codebuild_project" "app_build" {
  name          = "${var.project_name}-build"
  description   = "CodeBuild project for ${var.project_name}"
  build_timeout = "5" # minutes (adjust as needed)

  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0" # Choose an appropriate image
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = file("buildspec.yml") # Make sure buildspec.yml is in your root directory
  }

  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}


# E. AWS CodeDeploy Application and Deployment Group (for EC2)
resource "aws_codedeploy_app" "app" {
  name = var.codedeploy_application_name
}

resource "aws_codedeploy_deployment_group" "app_group" {
  app_name              = aws_codedeploy_app.app.name
  deployment_group_name = var.codedeploy_deployment_group_name
  service_role_arn      = aws_iam_role.codedeploy_service_role.arn # CORRECTED: Using the dedicated CodeDeploy service role

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
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
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
      owner            = "AWS" # MUST be AWS when using CodeStar Connections
      provider         = "CodeStarSourceConnection" # MUST be CodeStarSourceConnection
      version          = "1"

      configuration = {
        ConnectionArn     = "arn:aws:codestar-connections:ap-south-1:928096314836:connection/2e23edaa-5748-43a0-8275-7aeac3a44ecf" # Your specific ARN
        FullRepositoryId  = "${var.github_owner}/${var.github_repo}" # Format: Owner/Repo
        BranchName        = var.github_branch                        # The branch to build from
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
      input_artifacts   = ["BuildArtifact"]
      configuration = {
        ApplicationName     = aws_codedeploy_app.app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.app_group.deployment_group_name
      }
    }
  }

  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}