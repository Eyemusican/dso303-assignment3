variable "region" {
  default = "ap-southeast-1"
}

variable "prefix" {
  default = "tenzin-a3"
}

variable "azs" {
  default = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "image_tag" {
  default = "latest"
}

# ---- defaults are the final A3 design ----
# The load test runs overrode these with -var (see infra/load-test.md):
#   run 1 (A2 sizing): task_cpu=256 task_memory=512 gunicorn_threads=1 autoscaling=false
#   run 2 (fix):       task_cpu=1024 task_memory=2048 gunicorn_threads=4 autoscaling=true min_tasks=4

variable "task_cpu" {
  default = 512
}

variable "task_memory" {
  default = 1024
}

variable "gunicorn_threads" {
  default = 4
}

variable "desired_count" {
  default = 2
}

variable "autoscaling" {
  type    = bool
  default = true
}

# normal months: 2 tasks (1 per AZ). Before an exam I raise min_tasks to 10 (scheduled scaling).
variable "min_tasks" {
  default = 2
}

variable "max_tasks" {
  default = 10
}

# one NAT per AZ removes the single point of failure; set to 1 if the account is out of Elastic IPs
variable "nat_count" {
  default = 2
}

# design size; the shared class account is on the AWS free plan, so the tests used -var db_instance_class=db.t3.micro
variable "db_instance_class" {
  default = "db.t4g.medium"
}

# design is 7 days; the free plan only allows 1 day, so the tests used -var backup_retention=1
variable "backup_retention" {
  default = 7
}
