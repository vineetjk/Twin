#!/usr/bin/env bash
# Deploy Twin to Render from the render.yaml Blueprint.
#
#   npm run deploy:render                    check, then push the current branch (Render deploys on push)
#   SKIP_CHECKS=1 npm run deploy:render      skip the type check and tests
#   RENDER_DEPLOY_HOOKS="<url> <url>" npm run deploy:render
#                                            also call these deploy hooks (each service → Settings → Deploy Hook),
#                                            e.g. to redeploy without a new commit
#
# First deploy: open the Blueprint link printed at the end. Render creates twin-web, twin-backend and
# twin-vision from render.yaml and asks for MODEL_API_KEY; later pushes redeploy them.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f render.yaml ] || { echo "render.yaml not found." >&2; exit 1; }
branch=$(git rev-parse --abbrev-ref HEAD)
[ "$branch" != HEAD ] || { echo "Detached HEAD: check out the branch Render deploys first." >&2; exit 1; }
if [ -n "$(git status --porcelain)" ]; then
  echo "Uncommitted changes. Render builds from git, so commit or stash them first:" >&2
  git status --short >&2
  exit 1
fi

if [ "${SKIP_CHECKS:-}" != 1 ]; then
  node -e 'process.exit(+process.versions.node.split(".")[0] >= 22 ? 0 : 1)' \
    || { echo "The tests need Node.js 22 or later (node:sqlite); you have $(node --version). Upgrade, or rerun with SKIP_CHECKS=1." >&2; exit 1; }
  echo "→ Type check and tests"
  npm run --silent typecheck
  npm test --silent
  if [ -x .venv/bin/python ]; then npm run --silent test:backend; fi
fi

echo "→ Pushing $branch to origin"
git push origin "HEAD:$branch"

for hook in ${RENDER_DEPLOY_HOOKS:-}; do
  echo "→ Deploy hook ${hook%%\?*}"  # the query string holds the hook's secret key
  curl -fsS -X POST "$hook" >/dev/null
done

repo=$(git remote get-url origin | sed -E 's#^git@([^:]+):#https://\1/#; s#\.git$##')
cat <<EOF

Render redeploys the services whose files changed once it sees the push to '$branch'
(the Blueprint's branch, chosen when it was created). Follow the builds at https://dashboard.render.com

First deploy: https://render.com/deploy?repo=$repo
EOF
