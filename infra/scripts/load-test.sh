#!/bin/bash
# Burst of exam starts: 150 students hitting "start exam" at the same time for 3 minutes.
# This is harder than 3,000 starts spread over 5 min (10 per second), so it finds the limit.
# usage: bash scripts/load-test.sh 1     (run number, 1 = before fix, 2 = after fix)
set -e
export PATH=$HOME/bin:$PATH
RUN=${1:-1}
[ -x /tmp/hey ] || curl -sSLo /tmp/hey https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64 && chmod +x /tmp/hey
URL=$(terraform output -raw cloudfront_url)
echo "Start: $(date -u +%H:%M:%S) UTC"
/tmp/hey -z 3m -c 150 -m POST $URL/api/exams/1/start | tee load-run-$RUN.txt
echo "End: $(date -u +%H:%M:%S) UTC"
