# Failure tests

I ran these on the Singapore stack (ap-southeast-1) on 21 Nov 2026, then destroyed it.
Targets from the scenario: **RPO 5 min, RTO 1 hour, survive the loss of one AZ.**

Setup during the tests: 4 API tasks (1 vCPU / 2 GB) spread over 2 AZs, RDS PostgreSQL Multi-AZ (db.t3.micro, because the class account is on the AWS free plan).

**How I measured:** `scripts/probe.sh` runs in a second CloudShell tab. Once a second it saves an answer through the real path (CloudFront, ALB, ECS, RDS) and prints the time and HTTP code. Downtime = first failed call to first good call. Data loss = the last answer the probe saved compared with what the database returns afterwards.

## Results

| # | Scenario | How I caused it | Expected impact | Measured | RPO (5 min) | RTO (1 h) | Fix / likely solution |
|---|---|---|---|---|---|---|---|
| F1 | One API task crashes | `aws ecs stop-task` on a running task at 07:12:18 | The ALB stops sending to it and the other tasks keep serving. ECS starts a replacement. A request in flight might fail | ALB took the task out at 07:12:29 and ECS started a replacement at 07:12:30 (12 s). Probe: **53 OK, 0 failed** | Met (0, nothing lost) | Met (0, no downtime) | Already handled: at least 2 tasks in 2 AZs behind the ALB. The frontend also retries the autosave |
| F2 | Primary database lost (AZ failure of the DB) | `aws rds reboot-db-instance --force-failover` at 07:15:02 | The standby in the other AZ becomes primary and the DNS name moves to it. API errors while connections fail. No data lost, because Multi-AZ writes to both copies at the same time | Failover started 07:15:12, errors from **07:15:13 to 07:15:24 (about 12 s)**, back to OK at 07:15:25, AWS marked it complete at 07:15:51. Probe: 15 OK, 8 failed. Reading the attempt back returned `saved at 07:15:28`, the last answer the probe sent | Met (**0**, no saved answer lost) | Met (**about 12 s**) | Multi-AZ. The frontend keeps answers in the textarea and retries the autosave, so a student loses nothing during the 12 s. A connection pool with a retry would hide it from students completely |
| F3 | App tier in AZ a lost | `scripts/az-outage.sh start`, a deny all network ACL on the AZ a app subnet, 07:18:42 to 07:25:51 (7 min) | Tasks in AZ a fail ALB health checks and are taken out. AZ b carries all traffic. Some errors until the health check notices (up to 90 s with the default check) | Errors only from **07:18:48 to 07:19:56 (about 68 s)**, after that **6 minutes with no errors** while AZ a was still down. ECS replaced the lost tasks with new ones in AZ b: target health showed 3 healthy in 1b, AZ a draining or unhealthy. Probe: **372 OK, 15 failed** | Met (0) | Met (**about 68 s**) | Faster ALB health check: interval 10 s, 2 failures (now in `api.tf`), so a dead AZ is noticed in about 20 s. One NAT gateway per AZ so new tasks in AZ b can still pull images. Enough tasks that one AZ alone can carry the exam peak |
| F4 | Bad data written (a bug or wrong script overwrites answers). Multi-AZ copies the bad write too, so failover does not help | Point in time restore of the database to the latest restorable time | RDS ships transaction logs about every 5 minutes, so at most about 5 minutes of answers are lost. The restore builds a new DB, which takes 10 to 25 minutes | At 07:34:40 the latest restorable time was **07:30:25, 4 min 15 s behind**. Restore started 07:34:53, new DB available 07:45:38: **10 min 35 s**. Pointing the API at it (new `DB_HOST`, ECS redeploy) adds about 5 min, so about **16 min** in total | Met (**4 min 15 s**) | Met (**about 16 min**) | 7 day backup retention (the free plan test account allowed only 1 day), plus this written runbook. For records that must be kept 5 years, a monthly AWS Backup copy kept 5 years |

## Evidence

| File | Shows |
|---|---|
| `f1-probe.png` | probe all 200, 53 OK 0 failed |
| `f1-ecs-events.png` | stop at 07:12:18, deregistered 07:12:29, new task 07:12:30 |
| `f2-probe.png` | 200, then 000/500 for about 12 s, then 200 |
| `f2-rds-events.png` | failover started / completed, and the answer read back after failover |
| `f3-target-health.png` | AZ a cut off, AZ a targets draining or unhealthy, 3 healthy in AZ b |
| `f3-restored.png` | AZ a restored at 07:25:51 |
| `f3-probe.png` | 372 OK, 15 failed, first and last error |
| `f4-pitr.png` | latest restorable time vs clock, restore taking 10 min 35 s |

## Commands

```bash
# F1
TASK=$(aws ecs list-tasks --region ap-southeast-1 --cluster tenzin-a3-cluster --service-name tenzin-a3-api --query 'taskArns[0]' --output text)
aws ecs stop-task --region ap-southeast-1 --cluster tenzin-a3-cluster --task $TASK

# F2
aws rds reboot-db-instance --region ap-southeast-1 --db-instance-identifier tenzin-a3-db --force-failover
aws rds describe-events --region ap-southeast-1 --source-identifier tenzin-a3-db --source-type db-instance --duration 30

# F3
bash scripts/az-outage.sh start
aws elbv2 describe-target-health --region ap-southeast-1 --target-group-arn $(terraform output -raw alb_target_group_arn)
bash scripts/az-outage.sh stop

# F4
aws rds describe-db-instances --region ap-southeast-1 --db-instance-identifier tenzin-a3-db --query 'DBInstances[0].LatestRestorableTime'
aws rds restore-db-instance-to-point-in-time --region ap-southeast-1 \
  --source-db-instance-identifier tenzin-a3-db --target-db-instance-identifier tenzin-a3-db-restore \
  --use-latest-restorable-time --db-instance-class db.t3.micro --no-multi-az \
  --db-subnet-group-name tenzin-a3-db-subnets --no-publicly-accessible
time aws rds wait db-instance-available --region ap-southeast-1 --db-instance-identifier tenzin-a3-db-restore
# clean up, terraform does not manage this one
aws rds delete-db-instance --region ap-southeast-1 --db-instance-identifier tenzin-a3-db-restore --skip-final-snapshot --delete-automated-backups
```
