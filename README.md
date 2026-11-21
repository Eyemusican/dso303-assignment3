# DSO303 Assignment 3: Cost, Feasibility and Failure Testing

**Student:** Tenzin Namgay (Eyemusican) | **Region:** Asia Pacific (Singapore) ap-southeast-1 | **Prices checked:** 20 to 21 Nov 2026, AWS Pricing Calculator, USD

## Summary

This continues my Assignment 2 online exam platform (CloudFront, ALB, ECS Fargate, RDS PostgreSQL Multi-AZ, S3, SQS, Lambda). For Assignment 3 I moved it to Singapore, made it cheaper, priced a normal month and an exam month in the AWS Pricing Calculator, then deployed it for real with Terraform and tested it: a load test (bottleneck found in CloudWatch, fixed, retested) and 4 failure tests measured against the RPO and RTO. Everything was destroyed afterwards because we share one class AWS account.

## Feasibility verdict

**Feasible.** Average cost is **$327.23 a month** against a **$1,000** budget (worst month $400.94). RPO and RTO were met in every failure test: no saved answer was lost in a database failover, point in time restore was 4 min 15 s behind, and the longest outage was about 68 s when a whole AZ was cut off. The API handled **87 exam starts a second**, 8.7 times the peak of 10 a second. The one condition: the load test showed the small test database at 100% CPU, so the priced **db.t4g.medium** with a connection pool is required. Details: `docs/cost-report.md` section 5.

| Target | Result |
|---|---|
| Budget $1,000 a month | $327.23 average, $3,926.78 a year, **$1.31 per student per year** |
| Peak load | 87 starts/s tested (needed 10/s). DB upgrade required for autosaves |
| RPO 5 min | 0 for a failover, 4 min 15 s for a restore |
| RTO 1 hour | 0 s task crash, about 12 s DB failover, about 68 s AZ loss, about 16 min full restore |
| Survive one AZ loss | Yes, served from AZ b for 7 minutes |

## Calculator links

- **Normal month ($312.49):** https://calculator.aws/#/estimate?id=8a06bfecebaaf3cf05a7bd804488641222855e54
- **Exam month ($400.94):** https://calculator.aws/#/estimate?id=dc9b42969ba7bc4faca24aae808dcceb2e167214

Exports: `evidence/calculator-normal-month.pdf`, `evidence/calculator-exam-month.pdf`

## Demo video

My tutor confirmed no demo video is needed for this assignment, only screenshots and evidence. All evidence is in `evidence/` and listed below.

## Repository

| Folder | What is in it |
|---|---|
| `architecture/` | `architecture-diagram.png` (revised design with single points of failure S1 to S7 marked) and `change-log.md` (changes against A2 and how each single point of failure is removed or accepted) |
| `docs/cost-report.md` | Task 2: cost per service, hidden costs, top 3 components, 5 service comparisons, Singapore vs Mumbai, feasibility verdict |
| `infra/` | Terraform for the revised design, `failuretests.md` (4 scenarios with expected impact, measured result and fix), `load-test.md`, and the CloudShell scripts in `scripts/` |
| `app/` | The A2 API (Flask) and the Lambda notify function |
| `evidence/` | Calculator exports and all screenshots |

## Task 3: costed estimate and optimisations

| | Normal month | Exam month | Year (10 normal + 2 exam) |
|---|---|---|---|
| Calculator total | $312.49 | $400.94 | **$3,926.78** |

| # | Optimisation | Before | After | Saving |
|---|---|---|---|---|
| O1 | RDS 1 year Reserved, No Upfront instead of On‑Demand | $153.71/month | $122.69/month | **$31.02/month, $372.24/year** |
| O2 | Fargate on ARM (Graviton) instead of x86 | $44.98/month | $35.98/month | **$9.00/month (20%), about $120/year** |
| O3 | Scale out only for exams (2 tasks always, +8 during exams) instead of 10 tasks all month | $179.91/month | $35.98 normal, $59.64 exam | **about $1,680/year** |
| O4 | S3 lifecycle (Standard‑IA after 30 days) instead of all Standard | $3.94/month | $2.48/month | **$1.46/month (37%) in year 1, growing each year** |

Together the 4 optimisations save about **$2,189 a year** (the same design without them would be about $6,116 a year).

## How to run it

The state bucket and tools come from Assignment 2. From AWS CloudShell (Mumbai, where my Terraform is installed), deploying to Singapore:

```bash
cd /tmp && git clone https://github.com/Eyemusican/dso303-assignment3.git a3 && cd a3/infra
# the class account is on the AWS free plan, so the test uses a smaller DB and 1 day of backups
bash scripts/deploy.sh -var backup_retention=1 -var db_instance_class=db.t3.micro
bash scripts/load-test.sh 1 && bash scripts/metrics.sh     # see infra/load-test.md
bash scripts/probe.sh f1                                   # see infra/failuretests.md
terraform destroy -auto-approve -var backup_retention=1 -var db_instance_class=db.t3.micro
```

## Evidence

**Pricing (Task 2 and 3)**

| File | Shows |
|---|---|
| `calculator-normal-month.pdf` | Normal month, 12 services, $312.49 |
| `calculator-exam-month.pdf` | Exam month, 13 lines, $400.94 |
| `opt1-rds-ondemand.png`, `opt1-rds-reserved.png` | O1: RDS $153.71 On‑Demand vs $122.69 Reserved |
| `opt2-fargate-x86.png`, `opt2-fargate-arm.png` | O2: Fargate $44.98 x86 vs $35.98 ARM |
| `opt3-fargate-peak-always-on.png` | O3: 10 tasks all month would be $179.91 |
| `opt4-s3-all-standard.png`, `opt4-s3-lifecycle.png` | O4: S3 $3.94 all Standard vs $2.48 with lifecycle |
| `latency-from-bhutan.png` | Ping from Bhutan: Mumbai 57 ms, Singapore 85 ms |

**Load test**

| File | Shows |
|---|---|
| `load-run1-before.png` | Run 1 (A2 sizing): 31.4 requests/s, median 5.4 s |
| `load-run1-cloudwatch-1.png`, `load-run1-cloudwatch-2.png` | ECS CPU 100% while RDS CPU 40% and 4 connections: the API is the bottleneck |
| `load-fix-terraform-1.png`, `load-fix-terraform-2.png` | The fix: autoscaling 4 to 10 at 60% CPU, threads 1 to 4, CPU 256 to 1024, memory 512 to 2048 |
| `load-run2-after.png` | Run 2: 87 requests/s, median 1.6 s |
| `load-run2-cloudwatch-1.png`, `load-run2-cloudwatch-2.png` | ECS CPU down to about 40%, RDS CPU now 100% with 32 connections |

**Failure tests**

| File | Shows |
|---|---|
| `f1-probe.png`, `f1-ecs-events.png` | F1 task crash: 0 errors, replacement in 12 s |
| `f2-probe.png`, `f2-rds-events.png` | F2 DB failover: about 12 s of errors, last saved answer still there |
| `f3-target-health.png`, `f3-restored.png`, `f3-probe.png` | F3 AZ a cut off: AZ a unhealthy, 3 healthy tasks in AZ b, errors only in the first 68 s |
| `f4-pitr.png` | F4 point in time restore: 4 min 15 s behind, restore took 10 min 35 s |
| `destroy-complete.png` | Everything destroyed afterwards (61 resources) |

## Problems I faced

1. **The class account is on the AWS free plan.** My first deploy created everything except the database: RDS refused 7 days of backups, then refused `db.t4g.medium`. I made the backup days a variable and ran the tests with `db.t3.micro` and 1 day of backups. The design and the price stay at `db.t4g.medium` and 7 days. Point in time restore still worked with 1 day, so the RPO test was still valid.
2. **The `hey` load tool download link was broken.** I switched `scripts/load-test.sh` to ApacheBench (`ab`), which installs from the Amazon Linux packages.
3. **CloudShell disconnected and signed me out during long waits.** `/tmp` was wiped, so I cloned again and ran `terraform init` again. The Terraform state is in S3, so nothing was lost, and an interrupted `terraform destroy` just picked up where it stopped.
4. **The calculator would not let me leave the Regional NAT Gateway section empty.** I priced my 2 NAT gateways as 1 normal NAT plus 1 regional NAT in 1 AZ, which is the same hourly price. The total matches 2 NAT gateways exactly ($86.14 a month in hourly charges, plus data).
5. **CloudShell builds x86 images**, so the test tasks ran on x86 while the design and price use ARM. The code is the same; it only changes the image build.
