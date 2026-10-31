#!/usr/bin/env bash
set -euo pipefail
bash "$(dirname "$0")/../scaffold-common.sh"
git checkout -q -b widget-count
sed -i 's/echo $((n + 1))/echo "$n"/' widgets.sh
