#!/usr/bin/env python3
"""PAY-4371 NOC dashboard — one pane over ES + Jenkins mock (stdlib only).
Serves / (HTML, auto-refresh 5s) and /api/summary (JSON). Port 8090."""
import json, os, re, urllib.request, datetime

ES = os.environ.get("ES_URL", "http://localhost:9200")
JENKINS = os.environ.get("JENKINS_URL", "http://localhost:8085")
IDX = "payments-logs-*"

def es(q, body):
    req = urllib.request.Request(f"{ES}/{IDX}/_search", method="POST",
        headers={"Content-Type": "application/json"}, data=json.dumps(body).encode())
    return json.loads(urllib.request.urlopen(req, timeout=5).read())

def per_min(must, value=None):
    aggs = {"hist": {"date_histogram": {"field": "@timestamp", "fixed_interval": "1m"}}}
    if value:
        aggs["hist"]["aggs"] = {"v": value}
    r = es(None, {"size": 0, "query": {"bool": {"must": must}}, "aggs": aggs})
    out = []
    for b in r["aggregations"]["hist"]["buckets"]:
        v = b["v"]["value"] if value else b["doc_count"]
        out.append([b["key_as_string"][11:16], v if v is not None else 0])
    return out

def lag_series():
    r = es(None, {"size": 40, "sort": [{"@timestamp": "asc"}],
        "query": {"bool": {"must": [{"term": {"service.keyword": "fee-aggregator"}},
                                      {"match_phrase": {"message": "consumer lag"}}]}}})
    out = []
    for h in r["hits"]["hits"]:
        s = h["_source"]
        m = re.search(r"lag=(\d+)", s["message"])
        if m:
            out.append([s["@timestamp"][11:16], int(m.group(1))])
    return out

def rep_series():
    r = es(None, {"size": 40, "sort": [{"@timestamp": "asc"}],
        "query": {"bool": {"must": [{"term": {"service.keyword": "qlik-replicate"}}]}}})
    out = []
    for h in r["hits"]["hits"]:
        m = re.search(r"source_lag_s=(\d+)", h["_source"]["message"])
        if m:
            out.append([h["_source"]["@timestamp"][11:16], int(m.group(1))])
    return out

def summary():
    raw = json.loads(urllib.request.urlopen(f"{JENKINS}/api/jobs/payments-fee-service-deploy/builds", timeout=5).read())
    builds = raw["jobs"] if isinstance(raw, dict) and "jobs" in raw else raw
    lag = lag_series()
    return {
        "updated": datetime.datetime.now().strftime("%H:%M:%S"),
        "errors": per_min([{"term": {"level.keyword": "ERROR"}}]),
        "slow": per_min([{"match_phrase": {"message": "slow query"}}]),
        "lag": lag,
        "replag": rep_series(),
        "deploys": builds[:4],
        "totals": {
            "errors": sum(v for _, v in per_min([{"term": {"level.keyword": "ERROR"}}])),
            "peak_lag": max((v for _, v in lag), default=0),
            "docs": json.loads(urllib.request.urlopen(f"{ES}/{IDX}/_count", timeout=5).read())["count"],
        },
    }

PAGE = """<!doctype html><html><head><meta charset="utf-8"><title>PAY-4371 NOC</title>
<style>
:root{color-scheme:dark}
body{margin:0;background:#0b0f14;color:#d6e2ef;font:14px/1.4 ui-monospace,Menlo,monospace}
header{display:flex;justify-content:space-between;align-items:center;padding:10px 16px;border-bottom:2px solid #e5484d}
h1{font-size:16px;margin:0;color:#e5484d} .meta{color:#7d8ea3;font-size:12px}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:12px;padding:12px}
.tile{background:#121a24;border:1px solid #1f2c3c;border-radius:8px;padding:10px 12px}
.tile h2{font-size:12px;margin:0 0 6px;color:#7d8ea3;text-transform:uppercase;letter-spacing:.08em}
.big{font-size:22px;color:#fff} .warn{color:#ffb224} .bad{color:#e5484d}
svg{width:100%;height:90px;display:block}
table{border-collapse:collapse;width:100%;font-size:12px}
td,th{padding:3px 6px;text-align:left;border-bottom:1px solid #1f2c3c}
.badge{background:#e5484d;color:#fff;border-radius:4px;padding:1px 6px;font-size:11px}
footer{padding:8px 16px;color:#4d5f73;font-size:11px}
</style></head><body>
<header><h1>● PAY-4371 — payments-fee-service · prod-sg · settlement p99 breach</h1>
<span class="meta" id="upd"></span></header>
<div class="grid">
<div class="tile"><h2>HTTP 500 errors / min</h2><div class="big bad" id="etot"></div><svg id="err"></svg></div>
<div class="tile"><h2>Slow fee-rule queries / min (SeqScan)</h2><svg id="slow"></svg></div>
<div class="tile"><h2>Kafka lag — settlement.fees / fee-aggregator</h2><div class="big warn" id="ltot"></div><svg id="lag"></svg></div>
<div class="tile"><h2>Recent deploys (Jenkins)</h2><table id="dep"></table>
<h2 style="margin-top:8px">Qlik Replicate source lag (s)</h2><svg id="rep"></svg></div>
</div>
<footer>payments-logs-* @ localhost:9200 · Jenkins mock :8085 · incident window 01:50–02:35 SGT · refresh 5s</footer>
<script>
function chart(id,pts,color,fill){const s=document.getElementById(id);if(!pts.length)return;
const W=300,H=90,max=Math.max(...pts.map(p=>p[1]),1);
const x=i=>i*(W/(pts.length-1)),y=v=>H-4-(v/max)*(H-14);
const d=pts.map((p,i)=>`${i?'L':'M'}${x(i).toFixed(1)},${y(p[1]).toFixed(1)}`).join('');
s.innerHTML=`<path d="${d} L${W},${H} L0,${H} Z" fill="${fill}"/><path d="${d}" fill="none" stroke="${color}" stroke-width="2"/>
<text x="2" y="${H-1}" fill="#4d5f73" font-size="9">${pts[0][0]}</text>
<text x="${W-30}" y="${H-1}" fill="#4d5f73" font-size="9">${pts[pts.length-1][0]}</text>
<text x="${W-46}" y="12" fill="${color}" font-size="10">max ${max}</text>`}
async function tick(){const d=await (await fetch('/api/summary')).json();
document.getElementById('upd').textContent='updated '+d.updated+' · '+d.totals.docs+' docs';
document.getElementById('etot').textContent=d.totals.errors+' errors in window';
document.getElementById('ltot').textContent='peak lag '+d.totals.peak_lag.toLocaleString()+' msgs';
chart('err',d.errors,'#e5484d','#2a1216');chart('slow',d.slow,'#ffb224','#2a2210');
chart('lag',d.lag,'#4f9cf9','#12203a');chart('rep',d.replag,'#b5e853','#1c2a10');
document.getElementById('dep').innerHTML='<tr><th>build</th><th>commit</th><th>version</th><th>when</th></tr>'+
d.deploys.map(b=>`<tr><td>#${b.number}${b.number==4177?' <span class=badge>deployed 02:02</span>':''}</td>
<td>${b.commit}</td><td>${b.version}</td><td>${b.timestamp.slice(11,16)}</td></tr>`).join('');}
tick();setInterval(tick,5000);
</script></body></html>"""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        try:
            body = json.dumps(summary()).encode() if self.path.startswith("/api") \
                else PAGE.encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json" if self.path.startswith("/api") else "text/html")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers(); self.wfile.write(body)
        except Exception as e:
            msg = json.dumps({"error": str(e)}).encode()
            self.send_response(500); self.end_headers(); self.wfile.write(msg)

if __name__ == "__main__":
    print("NOC dashboard on :8090")
    ThreadingHTTPServer(("0.0.0.0", 8090), H).serve_forever()
