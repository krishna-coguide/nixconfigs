#!/usr/bin/env bash
# Offline, real Firefox/CLI regression: private HOME, local HTTP, two sessions.
set -euo pipefail
umask 077
work=$(mktemp -d)
export HOME="$work/home" XDG_CACHE_HOME="$work/cache"
unset DISPLAY WAYLAND_DISPLAY PLAYWRIGHT_CLI_SESSION PLAYWRIGHT_MCP_BROWSER PLAYWRIGHT_MCP_HEADLESS
mkdir -p "$HOME" "$work/project/artifacts/test-a" "$work/project/artifacts/test-b"
cd "$work/project"
server=''
cleanup() {
  status=$?
  if (( status )); then grep -h . "$work"/*.log || true; fi
  for session in test-a test-b; do
    timeout 15 playwright-cli -s="$session" close >/dev/null 2>&1 || true
  done
  if [[ -n $server ]]; then kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true; fi
  rm -rf "$work"
  return "$status"
}
trap cleanup EXIT
node - "$work/port" <<'JS' &
const http = require('http');
const fs = require('fs');
http.createServer((req, res) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.end(`<title>Playwright Firefox</title><h1>Firefox session test</h1>
    <button onclick="document.querySelector('h1').textContent='Clicked'">Save</button>`);
}).listen(0, '127.0.0.1', function () {
  fs.writeFileSync(process.argv[2], String(this.address().port));
});
JS
server=$!
for ((i=0; i<100; i++)); do [[ -s $work/port ]] && break; sleep 0.1; done
url="http://127.0.0.1:$(< "$work/port")"
# Simultaneous creation exercises shared registry initialization too.
PLAYWRIGHT_MCP_OUTPUT_DIR="$PWD/artifacts/test-a" timeout 60 playwright-cli -s=test-a open "$url" > "$work/a.log" 2>&1 &
a=$!
PLAYWRIGHT_MCP_OUTPUT_DIR="$PWD/artifacts/test-b" timeout 60 playwright-cli -s=test-b open "$url" > "$work/b.log" 2>&1 &
b=$!
wait "$a"
wait "$b"
playwright-cli list --json | jq -e '
  (.browsers | length) == 2 and
  all(.browsers[]; .browserType == "firefox" and .headed == false and .persistent == false)'
playwright-cli -s=test-a --raw eval 'navigator.userAgent' | grep -q Firefox
playwright-cli -s=test-a eval "localStorage.setItem('owner', 'alpha')"
playwright-cli -s=test-a eval "document.cookie = 'owner=alpha; path=/'"
playwright-cli -s=test-b --raw eval "localStorage.getItem('owner')" | jq -e '. == null'
playwright-cli -s=test-b --raw eval 'document.cookie' | jq -e '. == ""'
playwright-cli -s=test-b eval "localStorage.setItem('owner', 'beta')"
playwright-cli -s=test-b eval "document.cookie = 'owner=beta; path=/'"
playwright-cli -s=test-a --raw eval "localStorage.getItem('owner')" | jq -e '. == "alpha"'
playwright-cli -s=test-a --raw eval 'document.cookie' | jq -e '. == "owner=alpha"'
playwright-cli -s=test-a --raw run-code "async page => { await page.getByRole('button', { name: 'Save' }).click(); return page.getByRole('heading').innerText(); }" | jq -e '. == "Clicked"'
playwright-cli -s=test-b --raw eval "document.querySelector('h1').textContent" | jq -e '. == "Firefox session test"'
playwright-cli -s=test-a snapshot --filename="$PWD/artifacts/test-a/snapshot.yml"
playwright-cli -s=test-a screenshot --filename="$PWD/artifacts/test-a/page.png"
test -s artifacts/test-a/snapshot.yml && test -s artifacts/test-a/page.png
playwright-cli -s=test-a close
# Closing one subagent must leave the other's state and browser alive.
playwright-cli -s=test-b --raw eval "localStorage.getItem('owner')" | jq -e '. == "beta"'
playwright-cli -s=test-b --raw eval 'document.cookie' | jq -e '. == "owner=beta"'
playwright-cli -s=test-b close
playwright-cli list --json | jq -e '.browsers | length == 0'
# Reopening a closed, nonpersistent session must not restore authentication state.
playwright-cli -s=test-a open "$url"
playwright-cli -s=test-a --raw eval "localStorage.getItem('owner')" | jq -e '. == null'
playwright-cli -s=test-a --raw eval 'document.cookie' | jq -e '. == ""'
if [[ -n ${PLAYWRIGHT_TEST_OUTPUT:-} ]]; then
  mkdir -p "$PLAYWRIGHT_TEST_OUTPUT"
  cp artifacts/test-a/{snapshot.yml,page.png} "$PLAYWRIGHT_TEST_OUTPUT/"
fi
echo 'PASS: two concurrent headless Firefox sessions, isolated DOM/cookies/storage, screenshots, scoped cleanup and ephemeral profiles'
