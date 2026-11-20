# Load test

Peak in the scenario: 3,000 students start one exam within 5 minutes, which is about 10 starts a second.
I tested a harder burst, **150 students pressing start at the same moment, nonstop for 3 minutes** (`scripts/load-test.sh`), from CloudShell through CloudFront, so the request goes the same way a student's would (CloudFront, ALB, ECS, RDS).

## Run 1: A2 sizing (before the fix)

2 tasks, 256 CPU / 512 MB, gunicorn 2 workers, 1 thread, no autoscaling. DB db.t4g.medium Multi-AZ.

_TBD: hey summary (requests/sec, average and p99 latency, errors) and CloudWatch numbers_

**Bottleneck:** _TBD_

## Fix

_TBD_

## Run 2: after the fix

_TBD_

## Two more bottlenecks (reasoned, not tested)

_TBD_
