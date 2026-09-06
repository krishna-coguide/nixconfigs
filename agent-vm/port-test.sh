#!/usr/bin/env bash
# Real SSH forwards in an offline VM; listeners belong only to this test.
set -euo pipefail
launcher=$1
tmp=$(mktemp -d)
export HOME=$tmp/home DSH_HOME=$tmp/dsh DSH_AGENTS_HOME=$tmp/agents XDG_STATE_HOME=$tmp/state
mkdir -p "$HOME" "$tmp/project"
cd "$tmp/project"
state="$XDG_STATE_HOME/agent-vm/$(printf %s "$PWD" | sha256sum | cut -c1-16)"
vm_pid=''
listener=''
cleanup() {
  status=$?
  if (( status )); then
    grep -h . "$tmp/launcher.log" "$tmp/listeners.log" "$state/console.log" | tail -100 || true
  fi
  "$launcher" stop >/dev/null 2>&1 || true
  if [[ -n $vm_pid ]]; then kill "$vm_pid" 2>/dev/null || true; wait "$vm_pid" 2>/dev/null || true; fi
  if [[ -n $listener ]]; then kill "$listener" 2>/dev/null || true; wait "$listener" 2>/dev/null || true; fi
  rm -rf "$tmp"
  return "$status"
}
trap cleanup EXIT
reserve_through() {
  rm -f "$tmp/listeners-ready"
  node - "$1" "$tmp/listeners-ready" > "$tmp/listeners.log" 2>&1 <<'JS' &
const http = require('node:http');
const fs = require('node:fs');
const listeners = [];
for (let port = 3080; port <= Number(process.argv[2]); port++) {
  listeners.push(new Promise((resolve, reject) => {
    http.createServer((req, res) => res.end('occupied\n'))
      .on('error', reject).listen(port, '127.0.0.1', resolve);
  }));
}
Promise.all(listeners).then(() => fs.writeFileSync(process.argv[3], 'ready'));
JS
  listener=$!
  for ((i=0; i<100; i++)); do
    [[ ! -f $tmp/listeners-ready ]] || return 0
    kill -0 "$listener"
    sleep 0.1
  done
  echo 'Port fixture startup timed out' >&2; return 1
}
release_listeners() { kill "$listener"; wait "$listener" || true; listener=''; }
expect_port() {
  local expected=$1 login=''
  "$launcher" run > "$tmp/launcher.log" 2>&1 &
  vm_pid=$!
  for ((i=0; i<120; i++)); do
    kill -0 "$vm_pid"
    if login=$("$launcher" url 2>/dev/null); then break; fi
    sleep 1
  done
  [[ $login == "http://127.0.0.1:$expected/?token=offline-test" ]]
  [[ $(< "$state/web-port") == "$expected" ]]
  [[ $(curl --fail --silent --max-time 5 "$login") == agent-vm-test ]]
  if [[ -n $listener ]]; then
    [[ $(curl --fail --silent --max-time 5 http://127.0.0.1:3080/) == occupied ]]
  fi
  "$launcher" stop
  wait "$vm_pid"
  vm_pid=''
  [[ ! -e $state/web-port && ! -e $state/web.sock ]]
  if "$launcher" url >/dev/null 2>&1; then echo 'Stale URL after shutdown' >&2; return 1; fi
}
# Pick the first hole, then exercise the inclusive upper endpoint.
reserve_through 3082
expect_port 3083
release_listeners
reserve_through 3099
expect_port 3100
release_listeners
# Exhaustion must fail, shut down its VM, and not leave a remembered URL.
reserve_through 3100
if "$launcher" run > "$tmp/launcher.log" 2>&1; then echo 'Accepted a full port range' >&2; exit 1; fi
grep -Fq 'No available Web UI port on 127.0.0.1 in 3080-3100' "$tmp/launcher.log"
[[ ! -e $state/web-port && ! -e $state/web.sock ]]
if "$launcher" ssh true >/dev/null 2>&1; then echo 'VM survived failed launch' >&2; exit 1; fi
release_listeners
# A new run starts searching at 3080, not at the previously selected port.
expect_port 3080
echo 'PASS: first available port, inclusive 3100 endpoint, full-range failure, real HTTP forwarding, URL persistence and cleanup, restart from 3080'
