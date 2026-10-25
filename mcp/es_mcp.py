#!/usr/bin/env python3
"""Minimal stdlib MCP server (stdio, JSON-RPC 2.0) exposing Elasticsearch read tools.
Swap for Elastic's Agent Builder MCP endpoint (ES 9.2+) or elastic/mcp-server-elasticsearch in production."""
import json, os, sys, urllib.request

ES = os.environ.get("ES_URL", "http://localhost:9200")
TOOLS = [
    {"name": "search_es", "description": "Search Elasticsearch. Args: index (str), query (ES query_dsl object), size (int, default 20).",
     "inputSchema": {"type": "object", "properties": {"index": {"type": "string"}, "query": {"type": "object"}, "size": {"type": "integer"}}, "required": ["index", "query"]}},
    {"name": "es_count", "description": "Count matching docs. Args: index (str), query (ES query_dsl object).",
     "inputSchema": {"type": "object", "properties": {"index": {"type": "string"}, "query": {"type": "object"}}, "required": ["index"]}},
]

def rest(path, body=None):
    req = urllib.request.Request(ES + path, method="POST" if body else "GET",
        headers={"Content-Type": "application/json"},
        data=json.dumps(body).encode() if body else None)
    with urllib.request.urlopen(req) as r:
        return json.load(r)

def call_tool(name, args):
    if name == "search_es":
        q = {"query": args.get("query", {"match_all": {}}), "size": args.get("size", 20)}
        r = rest(f"/{args['index']}/_search", q)
        hits = [{"_id": h["_id"], **h["_source"]} for h in r["hits"]["hits"]]
        return {"total": r["hits"]["total"]["value"], "hits": hits}
    if name == "es_count":
        q = {"query": args.get("query", {"match_all": {}})}
        return {"count": rest(f"/{args['index']}/_count", q)["count"]}
    raise ValueError(f"unknown tool {name}")

def main():
    for line in sys.stdin:
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue
        m = msg.get("method")
        if m == "initialize":
            resp = {"protocolVersion": "2024-11-05", "capabilities": {"tools": {}},
                    "serverInfo": {"name": "elasticsearch-lab", "version": "0.1.0"}}
        elif m == "tools/list":
            resp = {"tools": TOOLS}
        elif m == "tools/call":
            p = msg["params"]
            try:
                resp = {"content": [{"type": "text", "text": json.dumps(call_tool(p["name"], p.get("arguments", {})))}], "isError": False}
            except Exception as e:
                resp = {"content": [{"type": "text", "text": f"error: {e}"}], "isError": True}
        elif m == "notifications/initialized":
            continue
        elif m == "ping":
            resp = {}
        else:
            if "id" not in msg:
                continue
            resp = {"error": {"code": -32601, "message": m}}
        if "id" in msg:
            print(json.dumps({"jsonrpc": "2.0", "id": msg["id"], **({"result": resp} if "error" not in resp else resp)}), flush=True)

if __name__ == "__main__":
    main()
