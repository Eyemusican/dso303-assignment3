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

# ---- sizes I change between the load test runs ----
# run 1 (A2 sizing): 256 CPU / 512 MB, 2 tasks, 1 thread, no autoscaling
# run 2 (fix):       1024 CPU / 2048 MB, 4 threads, autoscaling 4 to 10 tasks

variable "task_cpu" {
  default = 256
}

variable "task_memory" {
  default = 512
}

variable "gunicorn_threads" {
  default = 1
}

variable "desired_count" {
  default = 2
}

variable "autoscaling" {
  type    = bool
  default = false
}

variable "min_tasks" {
  default = 4
}

variable "max_tasks" {
  default = 10
}

# one NAT per AZ removes the single point of failure; set to 1 if the account is out of Elastic IPs
variable "nat_count" {
  default = 2
}

variable "db_instance_class" {
  default = "db.t4g.medium"
}

# design is 7 days; the shared class account is on the free plan, which only allows 1 day
variable "backup_retention" {
  default = 7
}
