#!/usr/bin/env python3
"""Seed synthetic logs for PAY-4371 into Elasticsearch (stdlib only)."""
import json, random, urllib.request, datetime

ES = "http://localhost:9200"
IDX = "payments-logs-2026.10.26"
BASE = datetime.datetime(2026, 10, 26, 2, 0, 0)

def t(minutes, seconds=0):
    return (BASE + datetime.timedelta(minutes=minutes, seconds=seconds)).strftime("%Y-%m-%dT%H:%M:%S.000Z")

def doc(ts, svc, level, msg, **extra):
    d = {"@timestamp": ts, "service": svc, "level": level, "message": msg,
         "env": "prod-sg", "trace_id": "%016x" % random.randrange(1 << 60)}
    d.update(extra); return d

docs = []
# baseline noise 01:50-02:30
for m in range(-15, 31):
    for _ in range(random.randint(15, 25)):
        docs.append(doc(t(m, random.randint(0, 59)), random.choice(
            ["payments-fee-service", "fee-aggregator", "settlement-gw"]),
            "INFO", random.choice(["fee calc ok", "settlement ack", "health ok", "cache hit"])))

# deploy marker 02:02
docs.append(doc(t(2, 14), "jenkins", "INFO",
    "deploy payments-fee-service v2.14.0 build=4177 commit=5904ad1 ns=prod-sg"))

# slow queries from 02:05, escalating
for m in range(5, 31):
    for _ in range(3):
        ms = 120 + (m - 5) * 90 + random.randint(0, 200)
        docs.append(doc(t(m, random.randint(0, 59)), "payments-fee-service", "WARN",
            f"slow query fee-rule lookup duration_ms={ms} plan=SeqScan table=fee_rules rows=200000",
            query="SELECT rate FROM fee_rules WHERE rule_key LIKE '%FEE_0137_9%'"))

# consumer lag from 02:06
lag = 0
for m in range(6, 31):
    lag += random.randint(1200, 2100)
    docs.append(doc(t(m, 30), "fee-aggregator", "WARN",
        f"kafka consumer lag topic=settlement.fees group=fee-aggregator lag={lag}"))

# replication lag (Qlik Replicate telemetry) from 02:10
for m in range(10, 31, 2):
    docs.append(doc(t(m, 5), "qlik-replicate", "WARN",
        f"task REP_SG_SETTLEMENT source_lag_s={30 + (m-10)*12} target=cloudera_staging status=delayed"))

# error spike from 02:14
for m in range(14, 31):
    for _ in range(random.randint(15, 30)):
        docs.append(doc(t(m, random.randint(0, 59)), "payments-fee-service", "ERROR",
            random.choice([
                "HTTP 500 on /fees/calculate: connection pool exhausted (pool=20, waiting=87)",
                "settlement fee calc timeout after 5000ms",
                "upstream settlement-gw 504"]),
            deploy_version="v2.14.0"))

req = urllib.request.Request(f"{ES}/{IDX}/_bulk", method="POST",
    headers={"Content-Type": "application/x-ndjson"},
    data=("\n".join(json.dumps({"index": {}}) + "\n" + json.dumps(d) for d in docs) + "\n").encode())
try:
    with urllib.request.urlopen(req) as r:
        out = json.load(r)
except urllib.error.HTTPError as e:
    print(e.read().decode()[:1500]); raise
print(f"indexed {len(docs)} docs, errors={out['errors']}")
