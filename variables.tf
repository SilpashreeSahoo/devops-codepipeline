variable "project_name" {
  description = "Name for the project and resources"
  type        = string
  default     = "devops-pipeline-project"
}

variable "s3_artifact_bucket_name" {
  description = "Name for the S3 artifact bucket"
  type        = string
  default     = "devops-codepipeline-artifacts"
}

variable "github_owner" {
  description = "GitHub repository owner (your GitHub username or organization)"
  type        = string
  # Example: default = "your-github-username" # YOU WILL PROVIDE THIS DURING 'terraform apply' or in a .tfvars file
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  # Example: default = "your-app-repo" # YOU WILL PROVIDE THIS DURING 'terraform apply' or in a .tfvars file
}

variable "github_branch" {
  description = "GitHub repository branch to use for the pipeline source"
  type        = string
  default     = "main"
}

variable "buildspec_path" {
  description = "Path to the buildspec.yml file in your source repository"
  type        = string
  default     = "buildspec.yml"
}

variable "codedeploy_application_name" {
  description = "Name for the CodeDeploy application"
  type        = string
  default     = "MyWebApp"
}

variable "codedeploy_deployment_group_name" {
  description = "Name for the CodeDeploy deployment group"
  type        = string
  default     = "MyWebAppDeploymentGroup"
}