# Load test

I ran this on the Singapore stack (ap-southeast-1) on 21 Nov 2026 from AWS CloudShell, then destroyed it.

**What the scenario needs:** 3,000 students start one exam within 5 minutes, which is about **10 starts a second**. After that the frontend autosaves every 30 seconds, which is about **100 small writes a second**.

**What I tested:** a harder burst. `scripts/load-test.sh` uses ApacheBench (`ab`) to keep **150 students pressing "start exam" at the same time, nonstop for 3 minutes** (`POST /api/exams/1/start`). Every request goes through CloudFront, the ALB, ECS and RDS, the same way a student's request would. Each start is a read of the questions plus an insert into `attempts`, so it is heavier than an autosave.

**Test account limit:** the shared class account is on the AWS free plan, which blocks `db.t4g.medium` and backups longer than 1 day. So the test database was **db.t3.micro Multi-AZ** with 1 day of backups. The design and the cost estimate keep **db.t4g.medium** and 7 days.

Commands I used (from `infra/`):

```bash
bash scripts/deploy.sh -var backup_retention=1 -var db_instance_class=db.t3.micro \
  -var task_cpu=256 -var task_memory=512 -var gunicorn_threads=1 -var autoscaling=false   # A2 sizing
bash scripts/load-test.sh 1
bash scripts/metrics.sh          # CloudWatch numbers per minute for the last 15 min
```

## Run 1: A2 sizing (before the fix)

2 tasks of 256 CPU / 512 MB, gunicorn 2 workers with 1 thread each, no autoscaling.

| Result (ab, 06:43:40 to 06:46:40 UTC) | Value |
|---|---|
| Requests completed | 5,655 |
| Requests per second | **31.4** |
| Failed | 0 |
| Median time | **5.4 s** |
| 95% of requests under | **9.2 s** |
| Slowest | 9.8 s |

| CloudWatch (1 minute values during the test) | Value |
|---|---|
| ECS CPUUtilization (max) | **97%, 100%, 100%, 100%** |
| ALB TargetResponseTime (avg) | 3.6 s, 4.2 s, 6.2 s, 4.2 s |
| ALB RequestCount | 701, 2,047, 1,441, 1,614 |
| ALB 5XX | none |
| RDS CPUUtilization (max) | 23%, 40%, 28% |
| RDS DatabaseConnections (max) | 4 |

**Bottleneck: the API tasks' CPU.** ECS CPU sat at 100% for the whole test while RDS was below half load. With 2 tasks x 2 workers x 1 thread, only 4 requests could run at once, so the other requests queued in front of the API, which is why a student waited 5 to 9 seconds. RDS only ever saw 4 connections, which proves the queue was in the API and not in the database.

Evidence: `load-run1-before.png`, `load-run1-cloudwatch-1.png`, `load-run1-cloudwatch-2.png`

## Fix

```bash
terraform apply -auto-approve -var image_tag=v1 -var backup_retention=1 -var db_instance_class=db.t3.micro \
  -var task_cpu=1024 -var task_memory=2048 -var gunicorn_threads=4 -var autoscaling=true
aws ecs update-service --region ap-southeast-1 --cluster tenzin-a3-cluster --service tenzin-a3-api --desired-count 4
```

1. Bigger tasks: 256 CPU / 512 MB to **1,024 CPU / 2,048 MB**.
2. **4 threads** per gunicorn worker, so each worker can serve another request while one waits on the database.
3. **Target tracking autoscaling** on 60% average CPU, 4 to 10 tasks.

Evidence: `load-fix-terraform-1.png` (autoscaling policy), `load-fix-terraform-2.png` (threads 1 to 4, CPU 256 to 1024, memory 512 to 2048)

## Run 2: after the fix

| Result (ab, 06:59:05 to 07:02:05 UTC) | Run 1 | Run 2 |
|---|---|---|
| Requests completed | 5,655 | **15,664** |
| Requests per second | 31.4 | **87.0** (2.8x) |
| Failed | 0 | 0 (1 non 2xx out of 15,664) |
| Median time | 5.4 s | **1.6 s** |
| 95% of requests under | 9.2 s | **4.0 s** |
| Slowest | 9.8 s | 5.4 s |

| CloudWatch | Run 1 | Run 2 |
|---|---|---|
| ECS CPU (max) | 100% | **38% to 42%** |
| ALB TargetResponseTime (avg) | 3.6 to 6.2 s | **1.6 to 1.7 s** |
| ALB requests per minute | about 1,400 to 2,000 | **about 5,100** |
| RDS CPU (max) | 40% | **99.8% to 100%** |
| RDS connections (max) | 4 | **32** |
| ECS tasks (desired / running) | 2 / 2 | 4 / 4 (CPU never reached 60%, so no scale out was needed) |

The fix worked for the API: CPU dropped from 100% to about 40% and the API served 2.8 times more requests, faster. **87 starts a second is 8.7 times the real peak of 10 a second.**

**The bottleneck moved to the database.** With 32 connections (4 tasks x 2 workers x 4 threads), the db.t3.micro was at 100% CPU. This is the reason the design keeps **db.t4g.medium** (4 GB memory instead of 1 GB) even though the free plan forced a micro for the test.

Evidence: `load-run2-after.png`, `load-run2-cloudwatch-1.png`, `load-run2-cloudwatch-2.png`

## Two more bottlenecks (reasoned, not tested)

1. **Database connections.** The API opens a new PostgreSQL connection for every request (`run_sql` in `app/api/app.py`). At 10 tasks that is up to 80 connections at once, which is near the limit for a micro instance (max_connections depends on memory), and every request also pays the connection setup time. **Fix:** a connection pool inside each worker (for example `psycopg2.pool`), or RDS Proxy if the pool is not enough. RDS Proxy would add cost, so I would try the pool first.
2. **Scale out is slower than the 5 minute spike.** Target tracking needs a few minutes of high CPU before it adds tasks, and a new Fargate task takes about 1 to 2 minutes to pull the image and pass health checks. A spike that lasts 5 minutes could be nearly over before new tasks arrive. **Fix:** scheduled scaling, raising min_tasks from 2 to 10 about 15 minutes before each exam and back to 2 afterwards. This is the "160 tasks x 6 hours" line in the exam month estimate.
