#!/usr/bin/env bash
# One-shot push of the app to a running eXist-db, over the same WebDAV endpoint
# watch-exist.sh uses. Unlike watch-exist.sh this does not wait for file changes —
# it uploads the current state of every tracked application file, so a local
# instance ends up matching the working tree exactly.
#
#   ./push-exist.sh              push files that differ from the last merge base
#   ./push-exist.sh --all        push every tracked application file
#   ./push-exist.sh --since REF  push files changed since REF (e.g. origin/develop)
#
# data/ is NEVER pushed. Research data on the server is not this script's business.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
EXIST_WEBDAV_BASE="${EXIST_WEBDAV_BASE:-http://localhost:8080/exist/webdav/db/apps/writerslibrary}"
EXIST_REST_BASE="${EXIST_REST_BASE:-http://localhost:8080/exist/rest/db/apps/writerslibrary}"
USER="${EXIST_USER:-admin}"
PASS="${EXIST_PASS:-}"

MODE="changed"
SINCE="origin/develop"
case "${1:-}" in
  --all)   MODE="all" ;;
  --since) MODE="changed"; SINCE="${2:?--since needs a ref}" ;;
  "")      ;;
  *)       echo "unknown option: $1" >&2; exit 2 ;;
esac

cd "$REPO_ROOT"

# Files eXist actually needs. Excludes dev-only files and, always, data/.
select_files () {
  if [ "$MODE" = all ]; then
    git ls-files
  else
    git diff --name-only "$SINCE" HEAD
  fi | grep -Ev '^(data/|test/|build\.xml|cypress\.config\.js|package(-lock)?\.json|\.git)' \
     | grep -E '\.(xql|xqm|xq|html|htm|css|js|json|xml|xconf|xsl|svg|png|jpg|jpeg|gif|woff2?|ttf|eot|md)$' \
     || true
}

# Read into an array without mapfile — macOS still ships bash 3.2.
FILES=()
while IFS= read -r line; do
  [ -n "$line" ] && FILES+=("$line")
done < <(select_files)

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "nothing to push (mode=$MODE${SINCE:+, since=$SINCE})"
  exit 0
fi

echo "Target:  $EXIST_WEBDAV_BASE"
echo "Pushing: ${#FILES[@]} file(s)"
echo

# WebDAV PUT will not create intermediate collections, so make them first.
printf '%s\n' "${FILES[@]}" | xargs -n1 dirname | sort -u | while read -r d; do
  [ "$d" = "." ] && continue
  curl -sS -u "$USER:$PASS" -X MKCOL "$EXIST_WEBDAV_BASE/$d" >/dev/null 2>&1 || true
done

failed=0
for rel in "${FILES[@]}"; do
  [ -f "$rel" ] || { echo "  skip (gone) $rel"; continue; }
  if curl -sS --fail -u "$USER:$PASS" -T "$rel" "$EXIST_WEBDAV_BASE/$rel" >/dev/null; then
    echo "  PUT  $rel"
    if [[ "$rel" =~ \.(xql|xqm|xq)$ ]]; then
      curl -sS -u "$USER:$PASS" -G "$EXIST_REST_BASE/$rel" \
        --data-urlencode "_query=sm:chmod(xs:anyURI('/db/apps/writerslibrary/$rel'),'rwxr-xr-x')" \
        --data-urlencode "_wrap=no" >/dev/null || true
    fi
  else
    echo "  FAIL $rel" >&2
    failed=$((failed+1))
  fi
done

echo
if [ "$failed" -gt 0 ]; then
  echo "$failed file(s) failed to upload." >&2
  exit 1
fi

# Compile check: importing the module forces eXist to parse it. A static error
# (undeclared prefix, syntax error, bad function signature) surfaces here rather
# than the first time someone loads a page.
echo "Compile check on modules/library-manager.xql:"
curl -sS -u "$USER:$PASS" -G "${EXIST_REST_BASE%/apps/writerslibrary}" \
  --data-urlencode '_query=import module namespace libmgr="http://exist-db.org/apps/writerslibrary/library-manager" at "/db/apps/writerslibrary/modules/library-manager.xql"; string-join(for $f in ("create-library","create-book","pages-from-directory-listing","check-directory-listing","get-book-doc","insert-pages-into-book","remove-pages-from-book") return $f || "=" || (if (exists(function-lookup(xs:QName("libmgr:" || $f), 1)) or exists(function-lookup(xs:QName("libmgr:" || $f), 2)) or exists(function-lookup(xs:QName("libmgr:" || $f), 3))) then "ok" else "MISSING"), " ")' \
  --data-urlencode '_wrap=no' || echo "  (compile check request failed — check the server log)"
echo
