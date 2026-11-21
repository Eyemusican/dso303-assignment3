#!/bin/bash
# Burst of exam starts: 150 students pressing "start exam" at the same time for 3 minutes.
# This is harder than 3,000 starts spread over 5 min (10 per second), so it finds the limit.
# usage: bash scripts/load-test.sh 1   (1 = before fix, 2 = after fix)
export PATH=$HOME/bin:$PATH
RUN=${1:-1}
command -v ab >/dev/null || sudo dnf install -y -q httpd-tools
URL=$(terraform output -raw cloudfront_url)
: > /tmp/empty.json
echo "Start: $(date -u +%H:%M:%S) UTC"
ab -t 180 -n 1000000 -c 150 -s 30 -r -l -p /tmp/empty.json -T application/json "$URL/api/exams/1/start" | tee load-run-$RUN.txt
echo "End: $(date -u +%H:%M:%S) UTC"
