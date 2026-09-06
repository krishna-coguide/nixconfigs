#!/usr/bin/env bash
# Required Web plugin, installed only inside the guest's live shared DSH home.
set -euo pipefail
profile="${DSH_HOME:?DSH_HOME must name the shared guest profile home}/profiles/web"
manifest="$profile/package.json"
spec=latest
if [[ -e $manifest ]]; then
  # Fail on malformed JSON instead of replacing a user's profile. Keep an
  # existing version/path spec when repairing an incomplete installation.
  configured=$(jq -r '.dependencies["dsh-context"] // empty' "$manifest")
  if [[ -n $configured ]]; then spec=$configured; fi
fi
installed() {
  [[ -f $manifest && -f $profile/node_modules/dsh-context/package.json ]] &&
    jq -e '.dependencies["dsh-context"] != null and
      ((.dsh.profile.bundles // []) | index("dsh-context") != null)' "$manifest" >/dev/null
}
if installed; then exit 0; fi
# Let upstream initialize/reconcile the profile; never generate its manifests,
# settings or credentials ourselves. No other plugin is added or updated here.
echo 'Installing dsh-context in the DSH web profile.' >&2
"$1" plugin --profile web add "dsh-context@$spec"
if ! installed; then
  echo 'dsh-context installation did not produce an installed Web bundle.' >&2
  exit 1
fi
