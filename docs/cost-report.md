# Cost and Service Report

All prices are from the **AWS Pricing Calculator**, region **Asia Pacific (Singapore) ap-southeast-1**, in **USD**, checked on **20 to 21 November 2026** (the estimate date is on both exports).

- Normal month estimate: https://calculator.aws/#/estimate?id=8a06bfecebaaf3cf05a7bd804488641222855e54 (`evidence/calculator-normal-month.pdf`)
- Exam month estimate: https://calculator.aws/#/estimate?id=dc9b42969ba7bc4faca24aae808dcceb2e167214 (`evidence/calculator-exam-month.pdf`)

**Load profiles I priced**

| | Normal month (10 a year) | Exam month (2 a year) |
|---|---|---|
| Users | 300 to 500 at once | 3,000 students start one exam within 5 minutes |
| API tasks | 2 always on (1 per AZ) | 2 always on + 8 extra for 6 hours on 20 exam days (160 task runs x 6 h) |
| CloudFront data out to India | 50 GB, 5 million requests | 200 GB, 20 million requests |
| ALB | 50 GB, 20 requests/s | 200 GB, 120 requests/s |
| NAT data processed | 10 GB | 30 GB |
| CloudWatch Logs | 5 GB | 20 GB |
| KMS requests | 200,000 | 500,000 |

## 1. Monthly cost per service, annual total and cost per student

| Service | What I priced | Normal month | Exam month |
|---|---|---|---|
| AWS Fargate (always on) | 2 tasks, ARM, 0.5 vCPU, 1 GB, 730 h | 35.98 | 35.98 |
| AWS Fargate (exam extra) | 160 tasks x 6 h, ARM, 0.5 vCPU, 1 GB | 0.00 | 23.66 |
| Amazon RDS for PostgreSQL | db.t4g.medium, Multi-AZ, gp3 20 GB, 1 yr Reserved No Upfront | 122.69 | 122.69 |
| Elastic Load Balancing | 1 ALB | 19.80 | 25.41 |
| Amazon VPC | 2 NAT gateways (1 per AZ) + data processed + 4 public IPv4 addresses | 101.32 | 102.52 |
| Amazon CloudFront | data out to India + data out to origin + HTTPS requests | 12.25 | 49.00 |
| AWS WAF | 1 web ACL, 3 rules, requests | 11.00 | 20.00 |
| Amazon S3 | 20 GB Standard + 130 GB Standard‑IA + requests | 2.48 | 3.24 |
| Amazon CloudWatch | logs ingested and stored, 6 alarms, 1 dashboard | 4.12 | 14.69 |
| AWS KMS | 1 customer managed key + requests | 1.60 | 2.50 |
| AWS Secrets Manager | 1 secret + 50,000 API calls | 0.65 | 0.65 |
| Amazon Route 53 | 1 hosted zone | 0.50 | 0.50 |
| Amazon ECR | 1 GB of images | 0.10 | 0.10 |
| **Total (calculator)** | | **312.49** | **400.94** |

**Annual total:** 10 x $312.49 + 2 x $400.94 = **$3,926.78**, which is an average of **$327.23 a month**.

**Cost per student:** $3,926.78 / 3,000 students = **$1.31 per student per year** (about $0.10 per student in a normal month and $0.13 in an exam month).

**Not in the calculator** (free tier or very small at our size): Cognito (3,000 users is under the 10,000 free monthly active users), Lambda and SQS (well under the free requests), SES (about 5,000 emails, under $1), CloudTrail (the first trail for management events is free), and the monthly AWS Backup copy of a 20 GB database kept 5 years (a few dollars a month at most). Even adding $5 a month for these, the year stays under $4,000.

### Hidden costs

| Hidden cost | Where it comes from | Normal month | Exam month |
|---|---|---|---|
| Data transfer out | CloudFront to students in India and Bhutan, plus CloudFront to the ALB, plus requests | 12.25 | 49.00 |
| NAT gateway processing | $0.059 per GB through the NAT (10 GB / 30 GB) | 0.59 | 1.77 |
| NAT gateway hours | 2 NATs x 730 h, charged even with no traffic | 86.14 | 86.14 |
| Public IPv4 addresses | 4 in use (2 NATs, 2 ALB nodes) at $3.65 each | 14.60 | 14.60 |
| CloudWatch Logs | ECS and Lambda logs, kept 30 days, plus alarms | 4.12 | 14.69 |
| KMS requests | every encrypt and decrypt call by S3, RDS and Secrets Manager, plus $1 for the key | 1.60 | 2.50 |
| Backups | RDS point in time restore for 7 days is free up to the 20 GB database size. Old S3 versions expire after 30 days | 0.00 | 0.00 |
| **Hidden total** | | **119.30 (38%)** | **168.70 (42%)** |

Over a third of the bill is costs that do not show up as "servers". The NAT hours alone cost more than all the API tasks. The calculator also does not take off the CloudFront free tier (1 TB and 10 million requests a month), so the real CloudFront bill would be close to $0. I left it in so the estimate stays on the safe side.

## 2. The three most expensive components

| Rank | Component | Normal month | Share | Why it costs this much |
|---|---|---|---|---|
| 1 | RDS PostgreSQL Multi-AZ | $122.69 | 39% | Multi-AZ runs **two** database instances all the time (the primary and the standby), so I pay twice. It runs 24/7 even when nobody is taking an exam. It is still the right choice because it removes the database single point of failure (test F2) |
| 2 | VPC: NAT gateways + public IPv4 | $101.32 | 32% | Each NAT gateway is charged by the hour whether traffic flows or not, and I need two so one AZ failing does not cut off the other (S1). Since 2024 AWS also charges for every public IPv4 address |
| 3 | Fargate | $35.98 normal, $59.64 exam | 12% to 15% | The API runs all the time. In exam months the extra tasks for the peak add $23.66 |

Together these three are 83% of a normal month. In an exam month CloudFront ($49.00) comes close to Fargate because the traffic is 4 times higher.

## 3. Service choices compared with an alternative

| Decision | Chosen | Alternative(s) | Cost | Performance | Resilience | Effort |
|---|---|---|---|---|---|---|
| **API compute** | ECS Fargate | EC2 Auto Scaling group; Lambda | Fargate 2 tasks ARM: **$35.98**. 2 x t4g.small EC2 would be about $31 a month (about $0.021 per hour, not from the calculator) but I would also pay for idle headroom | Fargate held 87 requests/s on 4 tasks (load test). Lambda has cold starts and would open one DB connection per request, which is the bottleneck I already found | Fargate and EC2 both spread over 2 AZs. Lambda is multi AZ by default | Fargate: no servers to patch. EC2: AMIs, patching, agents. Lambda: rewriting the Flask API and adding RDS Proxy. **Fargate wins on effort for similar cost** |
| **Database** | RDS PostgreSQL Multi-AZ, Reserved | Aurora Serverless v2; DynamoDB | RDS: **$122.69** (Reserved). Aurora Serverless v2 bills per ACU hour and needs a writer and a reader for Multi-AZ; it is cheaper only if load is low most of the time, but our normal months still have 300 to 500 users all day. DynamoDB on demand is cheap at low traffic | Load test run 2 showed a small RDS instance reaching 100% CPU, so size matters. Aurora scales up by itself, which helps the 5 minute spike | All three survive an AZ loss. Aurora fails over faster (usually under 30 s). DynamoDB has no failover at all | RDS: no code changes. Aurora: a small change (cluster endpoint). DynamoDB: rewrite all the SQL. **RDS with a reservation is the best fit now; Aurora Serverless v2 is the next step if the spike gets bigger** |
| **Outbound access** | 2 NAT gateways + free S3 gateway endpoint | VPC interface endpoints for ECR, CloudWatch Logs and Secrets Manager instead of NAT | NAT: **$86.14** + $0.059 per GB. 4 interface endpoints x 2 AZs is about $58 to $76 a month (about $0.01 to $0.013 per endpoint per AZ per hour) + $0.01 per GB | Same | Both are per AZ, so both survive an AZ loss | NAT works for any service. Endpoints need one per service, and anything new breaks until I add another. **Keep NAT now; move to endpoints if NAT data grows** |
| **Pricing model** | RDS 1 yr Reserved No Upfront; Fargate On‑Demand | On‑Demand; Reserved All Upfront; Savings Plans | RDS On‑Demand **$153.71**, Reserved No Upfront **$122.69** (−$31.02), Reserved All Upfront $1,299 once + $5.52 a month (about $113.77 a month). Compute Savings Plans would cut Fargate further, but the calculator does not support them for Fargate yet | Same | Same | A reservation locks me in for 1 year. **No Upfront keeps the monthly bill even without paying $1,299 at once** |
| **File storage** | S3 Standard → Standard‑IA (30 days) → Deep Archive (1 year) → delete (5 years) | Everything in Standard; Intelligent‑Tiering; Glacier Flexible Retrieval | All Standard **$3.94**, lifecycle **$2.48** (−37%) in year 1. The saving grows every year as more files reach Deep Archive. Intelligent‑Tiering adds a monitoring fee per object | Standard‑IA opens instantly. Deep Archive takes up to 12 hours, which is fine for 2 to 5 year old files | All S3 classes except One Zone keep copies in several AZs | One lifecycle rule in `uploads.tf`. **Lifecycle wins because the access pattern is known: files are read in the first weeks, then almost never** |

## 4. Singapore vs Mumbai (and latency for users in Bhutan)

| | Singapore (ap-southeast-1) | Mumbai (ap-south-1) |
|---|---|---|
| Latency from Bhutan (cloudping, `evidence/latency-from-bhutan.png`) | **85 ms** | **57 ms** (Hyderabad 68 ms) |
| Static pages and files | Served from CloudFront edges in India in both cases, so the region does not matter for them | Same |
| API calls (start, autosave) | +28 ms per call, which a student will not notice when autosave runs every 30 s | Slightly faster |
| Cost | The estimate above | Usually a little cheaper for compute and data out to India. I did not build a second full estimate |
| Free plan limits in our class account | Same | Same |
| Why chosen | The scenario asks for Singapore, and 85 ms is well within what an exam app needs | Would be my pick if the region were free to choose, because it is closer to Bhutan |

## 5. Feasibility verdict

| Target | Result | Evidence |
|---|---|---|
| **Budget** USD 1,000 a month on average | **Met.** $327.23 a month on average (33% of the budget), worst month $400.94. Even without any of the 4 optimisations the year would be about $6,116 ($510 a month) | Calculator exports, Task 3 |
| **Peak load** 3,000 starts in 5 minutes | **Met for starts, with a condition for autosaves.** The fixed API served **87 starts a second**, which is 8.7 times the 10 a second needed. Autosave adds about 100 small writes a second; at 87 requests a second the free plan **db.t3.micro** reached 100% CPU, so the design keeps **db.t4g.medium** plus a connection pool. That upgrade still needs a retest on a paid account | `infra/load-test.md` |
| **RPO** 5 minutes | **Met.** Multi-AZ failover lost no saved answer. Point in time restore was 4 min 15 s behind | `infra/failuretests.md` F2, F4 |
| **RTO** 1 hour | **Met.** Task crash: 0 s. DB failover: about 12 s. AZ loss: about 68 s (about 20 s with the new health check). Full restore from backup: about 16 min | F1 to F4 |
| **Survive the loss of one AZ** | **Met.** With AZ a cut off for 7 minutes, the app kept working from AZ b after the first 68 s | F3 |
| **Files kept 5 years** | **Met.** S3 lifecycle keeps files 5 years and deletes them after 1,825 days | `infra/uploads.tf` |

**Verdict: feasible.** The design runs at about a third of the budget and meets RPO, RTO and the AZ loss target in real tests. The one condition is the database: the load test showed a micro instance is too small for the exam peak, so the priced **db.t4g.medium** (with a connection pool) is required, not optional.
