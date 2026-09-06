#!/usr/bin/env bash
# Exercise the real setup script against an offline, strict DSH CLI fixture.
set -euo pipefail
setup=$1
dsh=$2
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" DSH_HOME="$tmp/dsh home"
mkdir -p "$HOME" "$DSH_HOME"
profile="$DSH_HOME/profiles/web"
manifest="$profile/package.json"
run() { bash "$setup" "$dsh"; }
calls() { wc -l < "$DSH_HOME/plugin-calls"; }

# Fresh home: upstream initializes Web, and only the requested plugin is added.
run
[[ $(< "$DSH_HOME/plugin-calls") == 'plugin --profile web add dsh-context@latest' ]]
jq -e '.dependencies | keys == ["dsh-context"]' "$manifest"
cp "$manifest" "$tmp/installed.json"
run
[[ $(calls) == 1 ]]
cmp "$manifest" "$tmp/installed.json"

# Existing home: preserve settings, credentials, patches, other profiles/plugins.
printf 'user settings\n' > "$DSH_HOME/settings.yaml"
printf 'fixture credentials, not real\n' > "$DSH_HOME/.credentials.yaml"
printf 'user patch\n' > "$profile/cordis.patch.yml"
mkdir -p "$DSH_HOME/profiles/headless"
printf '{"private":true}\n' > "$DSH_HOME/profiles/headless/package.json"
jq 'del(.dependencies["dsh-context"]) |
  .dependencies["user-plugin"] = "1.2.3" |
  .dsh.profile.bundles = ["@deepseek-ai/dsh-base", "@deepseek-ai/dsh-web-app", "user-plugin"] |
  .custom = {"keep":true}' "$manifest" > "$tmp/existing.json"
cp "$tmp/existing.json" "$manifest"
run
[[ $(calls) == 2 ]]
jq 'del(.dependencies["dsh-context"]) | .dsh.profile.bundles -= ["dsh-context"]' "$manifest" > "$tmp/preserved.json"
cmp "$tmp/existing.json" "$tmp/preserved.json"
[[ $(< "$DSH_HOME/settings.yaml") == 'user settings' ]]
[[ $(< "$DSH_HOME/.credentials.yaml") == 'fixture credentials, not real' ]]
[[ $(< "$profile/cordis.patch.yml") == 'user patch' ]]
[[ $(< "$DSH_HOME/profiles/headless/package.json") == '{"private":true}' ]]

# A selected version is not upgraded on restart, even when installation needs repair.
jq '.dependencies["dsh-context"] = "0.40.0"' "$manifest" > "$tmp/pinned.json"
cp "$tmp/pinned.json" "$manifest"
run
[[ $(calls) == 2 ]]
cmp "$manifest" "$tmp/pinned.json"
rm -rf "$profile/node_modules/dsh-context"
run
[[ $(calls) == 3 && $(tail -1 "$DSH_HOME/plugin-calls") == 'plugin --profile web add dsh-context@0.40.0' ]]
cmp "$manifest" "$tmp/pinned.json"
jq '.dsh.profile.bundles -= ["dsh-context"]' "$manifest" > "$tmp/unregistered.json"
cp "$tmp/unregistered.json" "$manifest"
run
[[ $(calls) == 4 ]]
cmp "$manifest" "$tmp/pinned.json"

# Partial failure must fail startup and be retried, not hidden behind a stamp.
rm -rf "$profile/node_modules/dsh-context"
touch "$DSH_HOME/fail-plugin-install"
if run; then echo 'Accepted a failed plugin install' >&2; exit 1; fi
[[ $(calls) == 5 && ! -e $profile/node_modules/dsh-context/package.json ]]
rm "$DSH_HOME/fail-plugin-install"
run
[[ $(calls) == 6 ]]
cmp "$manifest" "$tmp/pinned.json"
run
[[ $(calls) == 6 ]]

# Corrupt user data is an error, never permission to reset the profile.
printf 'not JSON\n' > "$manifest"
if run; then echo 'Accepted a malformed profile' >&2; exit 1; fi
[[ $(calls) == 6 && $(< "$manifest") == 'not JSON' ]]
echo 'PASS: context-only install, idempotence, profile preservation, selected version, incomplete install repair, failure/retry, malformed profile rejection'
