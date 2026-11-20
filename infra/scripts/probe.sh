#!/bin/bash
# Calls the API once a second and prints time + HTTP code, so I can measure downtime.
# usage (second CloudShell tab, infra folder): bash scripts/probe.sh <test name>
export PATH=$HOME/bin:$PATH
URL=$(terraform output -raw cloudfront_url)
ID=$(curl -s -X POST $URL/api/exams/1/start | python3 -c 'import sys,json;print(json.load(sys.stdin)["attempt_id"])')
echo "probing attempt $ID, Ctrl+C to stop"
while true; do
  CODE=$(curl -s -o /dev/null -m 3 -w '%{http_code}' -X PUT -H 'Content-Type: application/json' \
         -d "{\"answers\":\"saved at $(date -u +%T)\"}" $URL/api/attempts/$ID/answers)
  echo "$(date -u +%T) $CODE"
  sleep 1
done | tee -a probe-$1.log
