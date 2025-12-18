#!/usr/bin/env bash
set -euo pipefail
# Minimal headless smoke test: build with local tsc and run mocha to validate compiled artifact
WORKSPACE="/home/kavia/workspace/code-generation/hello-world-extension-2334-2350/vscode_extension_native"
cd "$WORKSPACE"
mkdir -p out-test
# create minimal smoke test if missing
if [ ! -f out-test/test-smoke.js ]; then cat > out-test/test-smoke.js <<'JS'
const fs = require('fs');const path = require('path');const assert = require('chai').assert;describe('smoke', function(){it('build artifact exists and exports activate', function(){const f=path.resolve(process.cwd(),'out','extension.js');assert.ok(fs.existsSync(f),'expected '+f+' to exist');const mod=require(f);assert.ok(mod && (typeof mod.activate==='function' || typeof mod.activate==='object'), 'expected activate export');});});
JS
fi
# Ensure local tsc and mocha exist
if [ ! -x "./node_modules/.bin/tsc" ]; then echo "ERROR: local tsc not found at ./node_modules/.bin/tsc" >&2; exit 2; fi
if [ ! -x "./node_modules/.bin/mocha" ]; then echo "ERROR: local mocha not found at ./node_modules/.bin/mocha" >&2; exit 2; fi
# Build using local tsc
./node_modules/.bin/tsc -p .
# Verify build artifact
[ -f out/extension.js ] || { echo "ERROR: build artifact out/extension.js missing" >&2; exit 3; }
# Run mocha tests (reporter spec)
./node_modules/.bin/mocha --reporter spec "out-test/**/*.js"
