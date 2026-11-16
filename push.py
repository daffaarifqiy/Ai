#!/usr/bin/env python3
"""Membaca config.json dan mengunggah files/, .github/workflows/build.yml, dan assets/ ke GitHub."""
import base64, json, sys, urllib.error, urllib.request
from pathlib import Path

DEPLOY = Path(__file__).parent.resolve()
CONFIG = DEPLOY / "config.json"
FILES = DEPLOY / "files"
ASSETS = DEPLOY / "assets"
BUILD_YML = DEPLOY / ".github" / "workflows" / "build.yml"   # ← path TETAP
API = "https://api.github.com"


def load_config():
    if not CONFIG.exists():
        sys.exit("❌ Buat config.json dulu (copy dari config.example.json)")
    cfg = json.loads(CONFIG.read_text(encoding="utf-8"))
    token = cfg.get("github_token", "").strip()
    url = cfg.get("repo_url", "").strip()
    if not token or not url:
        sys.exit("❌ github_token dan repo_url wajib diisi.")
    return token, url, cfg.get("branch", "main")


def parse_repo(url):
    url = url.strip().rstrip("/")
    if url.endswith(".git"):
        url = url[:-4]
    if "github.com/" in url:
        url = url.split("github.com/", 1)[1]
    parts = url.split("/")
    if len(parts) < 2:
        sys.exit(f"❌ Format repo URL tidak valid: {url}")
    return parts[0], parts[1]


def req(token, method, path, data=None):
    r = urllib.request.Request(f"{API}{path}", method=method)
    r.add_header("Authorization", f"token {token}")
    r.add_header("Accept", "application/vnd.github+json")
    r.add_header("User-Agent", "xdfaaa-push")
    if data is not None:
        r.add_header("Content-Type", "application/json")
        r.data = json.dumps(data).encode()
    try:
        with urllib.request.urlopen(r) as res:
            body = res.read().decode()
            return res.status, (json.loads(body) if body else {})
    except urllib.error.HTTPError as e:
        return e.code, (json.loads(e.read().decode()) if e.fp else {})


def upload(token, owner, repo, branch, path, blob, message=None):
    url = f"/repos/{owner}/{repo}/contents/{path}"
    sha = None
    s, r = req(token, "GET", f"{url}?ref={branch}")
    if s == 200:
        sha = r.get("sha")
    payload = {
        "message": message or f"Update {path}",
        "content": base64.b64encode(blob).decode(),
        "branch": branch,
    }
    if sha:
        payload["sha"] = sha
    s, r = req(token, "PUT", url, payload)
    if s in (200, 201):
        print(f"✅ {path}")
        return True
    print(f"❌ {path} -> {s} {r.get('message', '')}")
    return False


def main():
    token, repo_url, branch = load_config()
    owner, repo = parse_repo(repo_url)
    print(f"📦 Repo: {owner}/{repo} (branch {branch})")

    if not FILES.exists():
        sys.exit(f"❌ Folder {FILES} tidak ada.")

    ok = fail = 0

    # 1. Semua file di deploy/files/ → langsung ke path yang sama di repo
    for src in sorted(FILES.rglob("*")):
        if src.is_file():
            rel = src.relative_to(FILES).as_posix()
            if upload(token, owner, repo, branch, rel, src.read_bytes()):
                ok += 1
            else:
                fail += 1

    # 2. deploy/.github/workflows/build.yml → .github/workflows/build.yml (path sama)
    if BUILD_YML.exists():
        if upload(token, owner, repo, branch, ".github/workflows/build.yml",
                  BUILD_YML.read_bytes(), message="Update CI workflow"):
            ok += 1
        else:
            fail += 1
    else:
        print("⚠️ deploy/.github/workflows/build.yml tidak ditemukan.")

    # 3. Semua PNG di deploy/assets/ → root repo
    if ASSETS.exists():
        for png in sorted(ASSETS.glob("*.png")):
            if upload(token, owner, repo, branch, png.name, png.read_bytes(),
                      message=f"Add {png.name}"):
                ok += 1
            else:
                fail += 1

    print(f"\n✅ {ok} sukses, {fail} gagal")
    print("Buka GitHub → Actions → Build xdfaaa ai APK → Run workflow.")


if __name__ == "__main__":
    main()
