output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.main.domain_name}"
}

# the rest are used by the deploy and test scripts
output "frontend_bucket" {
  value = aws_s3_bucket.frontend.id
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.main.id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.api.repository_url
}

output "ecs_cluster" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service" {
  value = aws_ecs_service.api.name
}

output "alb_target_group_arn" {
  value = aws_lb_target_group.api.arn
}

output "db_identifier" {
  value = aws_db_instance.main.identifier
}

output "app_subnet_ids" {
  value = aws_subnet.app[*].id
}
