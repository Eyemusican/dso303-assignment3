# Change log: Assignment 2 to Assignment 3

The diagram is `architecture-diagram.png`. Single points of failure are the red notes S1 to S7 at the top, and the same tags appear next to the parts they belong to.

## Changes

| # | Area | Assignment 2 | Assignment 3 | Why (cost or test finding) |
|---|---|---|---|---|
| C1 | Region | ap-south-1 Mumbai | **ap-southeast-1 Singapore** | The A3 scenario asks for Singapore. Measured from Bhutan it is 85 ms against 57 ms for Mumbai (`latency-from-bhutan.png`), which is fine for an exam app |
| C2 | NAT gateways | Design had 1 per AZ, but the deployed stack ran **1 NAT** for both AZs because the class account ran out of Elastic IPs | **2 NAT gateways, 1 per AZ** (`nat_count = 2`), deployed and tested this time | One NAT was a single point of failure (S1). If its AZ fails, new tasks in the other AZ cannot pull images or read secrets |
| C3 | S3 traffic | All S3 and ECR layer traffic went through the NAT | Added a free **S3 gateway endpoint** on the app route tables | Cuts the NAT processing charge (a hidden cost) for image pulls and S3 uploads |
| C4 | API compute | 4 tasks minimum, 20 at peak, x86, 256 CPU / 512 MB, 1 thread | **ARM (Graviton) 0.5 vCPU / 1 GB, 4 threads, 2 tasks** in normal months (1 per AZ), **scheduled scaling to 10** for exams, CPU target tracking at 60% | Load test run 1 proved the 256 CPU tasks were the bottleneck (ECS CPU 100%). Graviton is 20% cheaper ($35.98 vs $44.98). Running peak size all month would cost $179.91 instead of $35.98 to $59.64 |
| C5 | Database | db.t3.micro Multi-AZ, on demand, 35 days of backups | **db.t4g.medium Multi-AZ, 1 year Reserved (No Upfront)**, 7 days of point in time restore | Load test run 2 showed the micro at 100% CPU with 32 connections, so it is the next bottleneck. Reserved saves $31.02 a month. 7 days is enough for restores. Test F4 proved RPO 4 min 15 s and RTO about 16 min |
| C6 | Long term records | AWS Backup daily, kept 5 years | **AWS Backup monthly, kept 5 years** | Daily copies are covered by the 7 day point in time restore, so monthly copies are enough for the 5 year rule and cost much less |
| C7 | Assignment files | Standard, then Standard‑IA after 30 days, Glacier after 1 year, delete after 5 years | Standard‑IA after 30 days, **Glacier Deep Archive** after 1 year, delete after 5 years, **versioning** with old versions removed after 30 days | Old files are almost never opened, so Deep Archive is the cheapest place for years 2 to 5. Lifecycle saves 37% in year 1 ($2.48 vs $3.94). Versioning protects against a file being deleted or overwritten |
| C8 | Logs | 7 day retention | **30 day retention**, 6 alarms, 1 dashboard | CloudWatch Logs is a hidden cost. 30 days keeps enough history for exam disputes without paying to store logs forever |
| C9 | Health check | ALB default (30 s interval, about 90 s to mark a target unhealthy) | **10 s interval, 2 failures** | Test F3: errors lasted about 68 s after AZ a was cut off, all from the slow health check. Now a dead AZ is noticed in about 20 s |
| C10 | Database connections | New connection for every request | Connection pool planned (RDS Proxy only if needed) | Load test reasoning: 10 tasks could open up to 80 connections. A pool is free, RDS Proxy is not |

Not changed, but kept on purpose: CloudFront (PriceClass_200, includes the India edges near Bhutan), WAF, Cognito, SQS with one DLQ, Lambda notify, SES, Secrets Manager, KMS, CloudTrail.

## Single points of failure

| Tag | Component | Removed or accepted | How | Proof |
|---|---|---|---|---|
| S1 | NAT gateway | **Removed** | 1 NAT per AZ, each app subnet uses the NAT in its own AZ | All tests ran with `nat_count = 2` (2 NAT gateways in the Terraform output) |
| S2 | API task | **Removed** | At least 2 tasks spread over 2 AZs behind the ALB, autoscaling 2 to 10 | F1: task killed, 0 errors. F3: AZ a cut off, ECS moved tasks to AZ b |
| S3 | Database primary | **Removed** | RDS Multi-AZ standby in the other AZ, same DNS name | F2: failover with about 12 s of errors and no saved answer lost |
| S4 | Bad data copied to the standby | **Removed** | Point in time restore (7 days) plus monthly AWS Backup | F4: RPO 4 min 15 s, restore 10 min 35 s |
| S5 | ALB, CloudFront, Route 53, WAF | **Accepted** | AWS runs these across many AZs or edge locations. The ALB has a node in both of my AZs | F3: the ALB kept serving from AZ b |
| S6 | Upload notification worker | **Removed** | SQS keeps messages for 4 days and moves a failing message to the DLQ after 3 tries, so nothing is lost if Lambda fails | Design (A2 walkthrough 2) |
| S7 | Whole region | **Accepted** | A second region would roughly double the bill. The RTO of 1 hour is met for an AZ loss. For a full region outage I would restore the latest backup in another region by hand, which would take longer than 1 hour. That risk is accepted for a college exam system | Reasoned |

## Code vs design

The Terraform in `infra/` has the design values as defaults. Two things differ only in the test deployment, and both are noted in the README:
- The shared class account is on the AWS free plan, so the tests used `db.t3.micro` and 1 day of backups (`-var db_instance_class=db.t3.micro -var backup_retention=1`).
- CloudShell builds x86 images, so the test tasks ran on x86. ARM needs an arm64 image build and `runtime_platform { cpu_architecture = "ARM64" }` in the task definition. The code is the same either way.
