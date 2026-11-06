#!/usr/bin/env python3
"""找本机上可用的 Apple 开发团队 ID，供 run-device.sh --personal 使用。

输出（每行一个团队，TSV）：TEAMID <tab> kind <tab> source
  kind：free（免费个人团队）/ paid / unknown；source：xcode（Xcode 登录的账号）/ cert（钥匙串里的 Apple Development 证书）
只输出 ID，不输出姓名 / 邮箱。来源：
  1. Xcode 账号：`defaults` 里 com.apple.dt.Xcode 的 IDEProvisioningTeamByIdentifier（含 isFreeProvisioningTeam）
  2. 钥匙串：Apple Development 证书的 subject OU（就是 Team ID），跳过已过期的
`--self-test` 用内置的假数据测试解析逻辑，不读本机。
"""
import plistlib
import re
import subprocess
import sys

TEAM_RE = re.compile(r"^[A-Z0-9]{10}$")


def teams_from_xcode_plist(obj, found=None):
    """递归找带 teamID 的字典（不依赖具体的层级，Xcode 版本之间结构略有不同）"""
    found = {} if found is None else found
    if isinstance(obj, dict):
        team = obj.get("teamID")
        if isinstance(team, str) and TEAM_RE.match(team):
            free = obj.get("isFreeProvisioningTeam")
            kind = "free" if free is True else "paid" if free is False else "unknown"
            if found.get(team, "unknown") == "unknown":
                found[team] = kind
        for value in obj.values():
            teams_from_xcode_plist(value, found)
    elif isinstance(obj, list):
        for value in obj:
            teams_from_xcode_plist(value, found)
    return found


def team_from_subject(subject):
    """`subject= UID=…, CN=Apple Development: …, OU=ABCDE12345, O=…, C=US`（或 RFC2253 写法）里取 OU"""
    for part in re.split(r"[,/]\s*", subject):
        key, _, value = part.strip().partition("=")
        if key.strip() == "OU" and TEAM_RE.match(value.strip()):
            return value.strip()
    return None


def xcode_teams():
    out = subprocess.run(["defaults", "export", "com.apple.dt.Xcode", "-"], capture_output=True).stdout
    try:
        return teams_from_xcode_plist(plistlib.loads(out))
    except Exception:
        return {}


def cert_teams():
    pems = subprocess.run(["security", "find-certificate", "-c", "Apple Development", "-a", "-p"],
                          capture_output=True, text=True).stdout
    teams = {}
    for block in re.findall(r"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", pems, re.S):
        def openssl(*args):
            return subprocess.run(["openssl", "x509", "-noout", *args], input=block, capture_output=True, text=True)
        if openssl("-checkend", "0").returncode != 0:   # 已过期
            continue
        team = team_from_subject(openssl("-subject", "-nameopt", "RFC2253").stdout.replace("subject=", "").strip())
        if team:
            teams.setdefault(team, "unknown")
    return teams


def merge(xcode, cert):
    merged = {}
    for source, teams in (("xcode", xcode), ("cert", cert)):
        for team, kind in teams.items():
            old_kind, sources = merged.get(team, ("unknown", []))
            merged[team] = (kind if old_kind == "unknown" else old_kind, sources + [source])
    return merged


def self_test():
    plist = {"IDEProvisioningTeamByIdentifier": {"a@example.invalid": [
        {"teamID": "AAAAA11111", "isFreeProvisioningTeam": True, "teamName": "x"},
        {"teamID": "BBBBB22222", "isFreeProvisioningTeam": False},
        {"teamID": "bad", "isFreeProvisioningTeam": True},
    ]}, "other": [{"nested": {"teamID": "CCCCC33333"}}]}
    assert teams_from_xcode_plist(plist) == {"AAAAA11111": "free", "BBBBB22222": "paid", "CCCCC33333": "unknown"}
    assert team_from_subject("UID=abc123, CN=Apple Development: Someone (XYZ), OU=DDDDD44444, O=Someone, C=US") == "DDDDD44444"
    assert team_from_subject("CN=Apple Development: x,OU=EEEEE55555,O=x,C=US") == "EEEEE55555"
    assert team_from_subject("CN=x, OU=tooshort, O=y") is None
    merged = merge({"AAAAA11111": "free"}, {"AAAAA11111": "unknown", "FFFFF66666": "unknown"})
    assert merged == {"AAAAA11111": ("free", ["xcode", "cert"]), "FFFFF66666": ("unknown", ["cert"])}
    print("detect-team self-test OK")


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        self_test()
    else:
        for team, (kind, sources) in sorted(merge(xcode_teams(), cert_teams()).items(), key=lambda kv: (kv[1][0] != "free", kv[0])):
            print(f"{team}\t{kind}\t{'+'.join(sources)}")
