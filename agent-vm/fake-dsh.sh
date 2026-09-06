# Offline CLI fixture only: no npm, network installs, credentials or model calls.
set -euo pipefail
profile="$DSH_HOME/profiles/web"
manifest="$profile/package.json"
if [[ ${1:-} == plugin ]]; then
  [[ $# == 5 && $2 == --profile && $3 == web && $4 == add && $5 == dsh-context@* ]]
  printf '%s\n' "$*" >> "$DSH_HOME/plugin-calls"
  mkdir -p "$profile"
  if [[ ! -e $manifest ]]; then
    printf '%s\n' '{"dsh":{"profile":{"bundles":["@deepseek-ai/dsh-base","@deepseek-ai/dsh-web-app"]}}}' > "$manifest"
  fi
  jq --arg spec "${5#dsh-context@}" '.dependencies["dsh-context"] = $spec' "$manifest" > "$manifest.tmp"
  mv "$manifest.tmp" "$manifest"
  # Simulate a failed install after pnpm has already recorded the dependency.
  [[ ! -e $DSH_HOME/fail-plugin-install ]] || exit 42
  mkdir -p "$profile/node_modules/dsh-context"
  printf '%s\n' '{"name":"dsh-context","version":"0.0.0"}' > "$profile/node_modules/dsh-context/package.json"
  jq '.dsh.profile.bundles |= (. + ["dsh-context"] | unique)' "$manifest" > "$manifest.tmp"
  mv "$manifest.tmp" "$manifest"
  exit 0
fi
[[ ${1:-} == web ]]
# The service must finish plugin setup before starting the Web listener.
[[ -f $profile/node_modules/dsh-context/package.json ]]
jq -e '.dsh.profile.bundles | index("dsh-context") != null' "$manifest" >/dev/null
exec node -e '
  require("node:http").createServer((req, res) => res.end("agent-vm-test"))
    .listen(3080, "127.0.0.1", () => console.log("http://127.0.0.1:3080/?token=offline-test"));
'
