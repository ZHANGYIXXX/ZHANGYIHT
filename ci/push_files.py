#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""经 GitHub API 推送文件到指定分支（仓库无本地 git，统一走这里）。

用法：python push_files.py <branch> <commit_msg_file> <file1> [file2 ...]
路径均相对仓库根（= 本目录的上一级，即 H:/Desktop/壹ZHANG核/V1/代码）。
"""
import base64
import json
import os
import ssl
import sys
import urllib.request
import urllib.error

TOKEN_FILE = os.path.join(os.path.dirname(__file__), "token.txt")
REPO = "ZHANGYIXXX/ZHANGYIHT"
API = "https://api.github.com"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

with open(TOKEN_FILE, encoding="utf-8") as f:
    TOKEN = f.read().strip()

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE


def api(method, path, data=None):
    req = urllib.request.Request(
        API + path,
        data=json.dumps(data).encode() if data is not None else None,
        method=method,
    )
    req.add_header("Authorization", "Bearer " + TOKEN)
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, context=ctx) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code}: {e.read().decode()[:400]}") from e


def main() -> int:
    if len(sys.argv) < 4:
        print(__doc__, file=sys.stderr)
        return 2
    branch, msg_file, files = sys.argv[1], sys.argv[2], sys.argv[3:]
    with open(msg_file, encoding="utf-8") as f:
        msg = f.read().strip()

    head = api("GET", f"/repos/{REPO}/git/refs/heads/{branch}")
    head_sha = head["object"]["sha"]
    base_tree = api("GET", f"/repos/{REPO}/git/commits/{head_sha}")["tree"]["sha"]
    print(f"{branch} head: {head_sha}")

    tree = []
    for rel in files:
        local = os.path.join(ROOT, rel.replace("/", os.sep))
        with open(local, "rb") as f:
            content = base64.b64encode(f.read()).decode()
        b = api("POST", f"/repos/{REPO}/git/blobs", {"content": content, "encoding": "base64"})
        tree.append({"path": rel, "mode": "100644", "type": "blob", "sha": b["sha"]})
        print("blob", rel, b["sha"][:10])

    new_tree = api("POST", f"/repos/{REPO}/git/trees", {"base_tree": base_tree, "tree": tree})
    commit = api("POST", f"/repos/{REPO}/git/commits",
                 {"message": msg, "tree": new_tree["sha"], "parents": [head_sha]})
    api("PATCH", f"/repos/{REPO}/git/refs/heads/{branch}", {"sha": commit["sha"]})
    print(f"PUSHED {branch}: {commit['sha']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
