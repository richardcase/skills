#!/usr/bin/env bash
# Builds the fixture repository in the eval workspace (cwd): signed commits via
# a throwaway ssh key, a tiny project with one test, and a local bare origin.
set -euo pipefail
ssh-keygen -q -t ed25519 -N '' -C eval -f ./.signkey
printf 'eval %s\n' "$(cat ./.signkey.pub)" > ./.allowed_signers
git init -q -b main .
git config user.name "Eval User"; git config user.email eval@example.com
git config gpg.format ssh; git config user.signingkey "$PWD/.signkey.pub"
git config commit.gpgsign true; git config gpg.ssh.allowedSignersFile "$PWD/.allowed_signers"
printf '.signkey\n.signkey.pub\n.allowed_signers\ncalls.log\nworktrees/\norigin.git/\n' > .gitignore
cat > widgets.sh <<'SH'
#!/usr/bin/env bash
# count widgets listed in a file, one per line
count_widgets() { local n; n=$(grep -c . "$1"); echo $((n + 1)); }
SH
cat > test.sh <<'SH'
#!/usr/bin/env bash
set -e; cd "$(dirname "$0")"; . ./widgets.sh
printf 'a\nb\nc\n' > "${TMPDIR:-/tmp}/eval-widgets.txt"
got=$(count_widgets "${TMPDIR:-/tmp}/eval-widgets.txt")
[ "$got" = 3 ] && echo "PASS count_widgets=3" || { echo "FAIL expected 3 got $got"; exit 1; }
SH
printf '# widgets\n\nA tiny fixture project.\n' > README.md
git add -A && git commit -q -m "initial fixture"
git init -q --bare ./origin.git && git remote add origin "$PWD/origin.git" && git push -q -u origin main
