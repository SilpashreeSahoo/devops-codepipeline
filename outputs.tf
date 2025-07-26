output "s3_artifact_bucket_name" {
  description = "Name of the S3 artifact bucket"
  value       = aws_s3_bucket.codepipeline_artifacts.bucket
}

variable "ap-south-1" {
  default = ""
}
output "codepipeline_url" {
  description = "URL of the created CodePipeline"
  value       = "https://${var.ap-south-1}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${aws_codepipeline.app_pipeline.name}/view?region=${var.ap-south-1}"
}

output "codebuild_project_name" {
  description = "Name of the CodeBuild project"
  value       = aws_codebuild_project.app_build.name
}