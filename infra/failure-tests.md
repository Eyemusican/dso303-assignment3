# Failure tests

I ran these on the Singapore stack (ap-southeast-1) on 20 Nov 2026, then destroyed it.
Targets from the scenario: **RPO 5 min, RTO 1 hour, survive the loss of one AZ.**

How I measured: `scripts/probe.sh` runs in a second CloudShell tab and saves an answer through the API once a second, printing the time and HTTP code. Downtime = first failed call to first good call. Data loss = compare the last saved answer before the failure with what is in the database after.

| # | Scenario | How I caused it | Expected impact | Measured | RPO met? | RTO met? | Likely solution / fix |
|---|---|---|---|---|---|---|---|
| F1 | One API task crashes | `aws ecs stop-task` on one of the running tasks | ALB stops sending to it, the other tasks keep serving. ECS starts a replacement in about a minute. A few requests in flight may fail | _TBD_ | _TBD_ | _TBD_ | Keep at least 2 tasks in 2 AZs, client retries the autosave |
| F2 | Primary database lost (AZ failure of the DB) | `aws rds reboot-db-instance --force-failover` | Standby in the other AZ becomes primary, DNS name moves to it. API errors for 1 to 2 min while connections fail. No data lost because Multi-AZ writes to both copies (synchronous) | _TBD_ | _TBD_ | _TBD_ | Multi-AZ, plus the frontend retrying the autosave so the student loses nothing |
| F3 | App tier in AZ a lost | `scripts/az-outage.sh start`, a deny-all network ACL on the AZ a app subnet | Tasks in AZ a fail ALB health checks and are taken out. AZ b tasks carry all traffic. Some errors until health checks mark AZ a unhealthy (up to 90 s with the default check) | _TBD_ | _TBD_ | _TBD_ | Faster health check (10 s, 2 failures), run enough tasks that one AZ alone can carry the exam peak, NAT gateway per AZ so new tasks in AZ b can still pull images |
| F4 | Bad data written (bug or wrong script overwrites answers) | Point in time restore of the DB to just before the bad write | Multi-AZ copies the bad data too, so I need a restore. RDS keeps transaction logs every 5 min, so I lose at most 5 min of answers. Restore makes a new DB, which takes around 15 to 25 min, under the 1 hour RTO | _TBD_ | _TBD_ | _TBD_ | 7 day backup retention, a tested restore runbook, then point the API at the restored DB |

## Commands

```bash
# F1
TASK=$(aws ecs list-tasks --region ap-southeast-1 --cluster tenzin-a3-cluster --service-name tenzin-a3-api --query 'taskArns[0]' --output text)
date -u +%T; aws ecs stop-task --region ap-southeast-1 --cluster tenzin-a3-cluster --task $TASK --query 'task.lastStatus'

# F2
date -u +%T; aws rds reboot-db-instance --region ap-southeast-1 --db-instance-identifier tenzin-a3-db --force-failover --query 'DBInstance.DBInstanceStatus'

# F3
bash scripts/az-outage.sh start
# watch the probe for 3 min, then
bash scripts/az-outage.sh stop

# F4
aws rds describe-db-instances --region ap-southeast-1 --db-instance-identifier tenzin-a3-db --query 'DBInstances[0].LatestRestorableTime'; date -u
date -u +%T; aws rds restore-db-instance-to-point-in-time --region ap-southeast-1 \
  --source-db-instance-identifier tenzin-a3-db --target-db-instance-identifier tenzin-a3-db-restore \
  --use-latest-restorable-time --db-instance-class db.t4g.medium --no-multi-az \
  --db-subnet-group-name tenzin-a3-db-subnets --no-publicly-accessible --query 'DBInstance.DBInstanceStatus'
time aws rds wait db-instance-available --region ap-southeast-1 --db-instance-identifier tenzin-a3-db-restore
# clean up, terraform does not know about this one
aws rds delete-db-instance --region ap-southeast-1 --db-instance-identifier tenzin-a3-db-restore --skip-final-snapshot --delete-automated-backups --query 'DBInstance.DBInstanceStatus'
```
