#!/usr/bin/env bash
set -euo pipefail
# Validation: build, optional esbuild bundle, package with vsce (local or npx), run @vscode/test-electron integration tests
WORKSPACE="/home/kavia/workspace/code-generation/hello-world-extension-2334-2350/vscode_extension_native"
cd "$WORKSPACE"
# Temporary logs (atomic tmp creation)
TMPLOG=$(mktemp -p /tmp vscode_vsce_log.XXXXXX) || { echo "ERROR: cannot create tmp" >&2; exit 6; }
TEST_LOG=$(mktemp -p /tmp vscode_test_log.XXXXXX) || { rm -f "$TMPLOG" || true; echo "ERROR: cannot create tmp" >&2; exit 6; }
# Ensure cleanup and diagnostic printing on errors
trap 'rc=$?; rm -f "$TMPLOG" "$TEST_LOG" 2>/dev/null || true; exit $rc' EXIT
trap 'rc=$?; echo "--- VALIDATION FAILURE - showing last 200 lines of logs ---" >&2; tail -n 200 "$TEST_LOG" 2>/dev/null || true; tail -n 200 "$TMPLOG" 2>/dev/null || true; rm -f "$TMPLOG" "$TEST_LOG" 2>/dev/null || true; exit $rc' ERR
# Build with local tsc
if [ -x ./node_modules/.bin/tsc ]; then
  ./node_modules/.bin/tsc -p .
else
  # fallback to global tsc if present
  if command -v tsc >/dev/null 2>&1; then tsc -p .; else echo "ERROR: tsc not available. Ensure typescript is installed." >&2; exit 2; fi
fi
# Optional bundling with esbuild if available and compiled artifact exists
if [ -x ./node_modules/.bin/esbuild ] && [ -f out/extension.js ]; then
  ./node_modules/.bin/esbuild out/extension.js --bundle --platform=node --outfile=out/extension.bundle.js || true
fi
# Determine package file name
PKG_VERSION=$(node -p "require('./package.json').version||'0.0.0'")
PACKAGE_FILE="$WORKSPACE/hello-world-extension-${PKG_VERSION}.vsix"
# Package via local vsce or npx fallback, capturing logs
if [ -x ./node_modules/.bin/vsce ]; then
  ./node_modules/.bin/vsce package -o "$PACKAGE_FILE" >"$TMPLOG" 2>&1 || { echo "ERROR: vsce packaging failed, printing tail of log:" >&2; tail -n 200 "$TMPLOG" >&2; exit 6; }
else
  npx --yes vsce package -o "$PACKAGE_FILE" >"$TMPLOG" 2>&1 || { echo "ERROR: npx vsce packaging failed, printing tail of log:" >&2; tail -n 200 "$TMPLOG" >&2; exit 7; }
fi
# Prepare integration harness that invokes runTests with extensionDevelopmentPath
mkdir -p .vscode-test/runner
cat > .vscode-test/index.js <<'JS'
const path = require('path');
const { runTests } = require('@vscode/test-electron');
async function main(){
  try{
    const extensionDevelopmentPath = path.resolve(process.cwd());
    const extensionTestsPath = path.resolve(process.cwd(), '.vscode-test', 'runner');
    await runTests({ extensionDevelopmentPath, extensionTestsPath });
    console.log('INTEGRATION_TESTS_PASSED');
    process.exit(0);
  }catch(err){
    console.error(err);
    process.exit(8);
  }
}
main();
JS
cat > .vscode-test/runner/index.js <<'JS'
const assert = require('assert');
const fs = require('fs');
const path = require('path');
module.exports = function () {
  describe('extension activation', function () {
    it('activation marker exists (with retries)', function (done) {
      this.timeout(300000);
      const marker = path.join(__dirname, '..', '..', 'out', 'activated.txt');
      const max = 30; let tries = 0;
      const iv = setInterval(() => {
        tries++;
        if (fs.existsSync(marker)) { clearInterval(iv); return done(); }
        if (tries >= max) { clearInterval(iv); return done(new Error('activation marker not found: ' + marker)); }
      }, 1000);
    });
  });
};
JS
# Run integration tests (runTests will download VS Code test host if needed)
node .vscode-test/index.js >"$TEST_LOG" 2>&1 || { echo "ERROR: integration tests failed, tailing log:" >&2; tail -n 200 "$TEST_LOG" >&2; exit 8; }
# Evidence outputs (non-fatal)
./node_modules/.bin/tsc --version || true
ls -la node_modules/.bin || true
ls -lh "$PACKAGE_FILE" || true
ls -la out || true
echo "VALIDATION_COMPLETE"
exit 0
