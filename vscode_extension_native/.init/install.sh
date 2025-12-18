#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/hello-world-extension-2334-2350/vscode_extension_native"
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"
# Validate node & npm
command -v node >/dev/null 2>&1 || { echo "ERROR: node not found" >&2; exit 2; }
command -v npm >/dev/null 2>&1 || { echo "ERROR: npm not found" >&2; exit 3; }
echo "node=$(node --version) npm=$(npm --version)"
# Persist NODE_ENV=development idempotently
TMPFILE=$(mktemp -p /tmp nodeenv.XXXXXX) || { echo "ERROR: cannot create tmp" >&2; exit 4; }
echo "export NODE_ENV=development" > "$TMPFILE"
sudo mv -f "$TMPFILE" /etc/profile.d/node_env.sh
# Ensure minimal scaffold exists (non-destructive)
if [ ! -f package.json ]; then cat > package.json <<'PKG'
{
  "name": "hello-world-extension",
  "version": "0.0.1",
  "engines": { "vscode": "^1.80.0" },
  "main": "out/extension.js",
  "scripts": { "vscode:prepublish": "npm run build", "build": "tsc -p .", "test": "mocha --timeout 10000" }
}
PKG
fi
if [ ! -f tsconfig.json ]; then cat > tsconfig.json <<'TS'
{
  "compilerOptions": { "module": "commonjs", "target": "ES2020", "outDir": "out", "rootDir": "src", "strict": true, "esModuleInterop": true }
}
TS
fi
mkdir -p src
if [ ! -f src/extension.ts ]; then cat > src/extension.ts <<'TS'
import * as vscode from 'vscode';
export function activate(context: vscode.ExtensionContext) { require('fs').writeFileSync('.activated','ok'); }
export function deactivate() {}
TS
fi
if [ ! -f .vscodeignore ]; then cat > .vscodeignore <<'VSI'
node_modules
.vscode
.vscode-test
.out
VSI
fi
# Merge required devDependencies idempotently, aligning @types/node major to runtime
node <<'NODE'
const fs=require('fs');const p='package.json';if(!fs.existsSync(p)){console.error('package.json missing');process.exit(2);}const obj=JSON.parse(fs.readFileSync(p));obj.devDependencies=obj.devDependencies||{};const semverNode=process.versions.node.split('.')[0];const typesNodeMajor=(+semverNode)>=20?"^20.0.0":"^18.0.0";const req={"typescript":"^5.0.0","@types/node":typesNodeMajor,"vscode":"^1.1.65","@types/vscode":"^1.80.0","@vscode/test-electron":"^2.0.0","vsce":"^2.0.0","esbuild":"^0.18.0","mocha":"^10.0.0","chai":"^4.0.0"};let changed=false;for(const k of Object.keys(req)){if(!obj.devDependencies[k]){obj.devDependencies[k]=req[k];changed=true}}if(changed)fs.writeFileSync(p,JSON.stringify(obj,null,2));
NODE
# Install with log capture and one retry
INSTALL_LOG=$(mktemp -p /tmp npm_install_log.XXXXXX) || { echo "ERROR: cannot create tmp log" >&2; exit 6; }
trap 'rm -f "$INSTALL_LOG" || true' EXIT
if [ -f package-lock.json ]; then
  npm ci --no-audit --no-fund >"$INSTALL_LOG" 2>&1 || (tail -n 200 "$INSTALL_LOG" >&2; echo "npm ci failed, retrying with npm i" >&2; npm i --no-audit --no-fund >"$INSTALL_LOG" 2>&1 || (tail -n 200 "$INSTALL_LOG" >&2; exit 7))
else
  npm i --no-audit --no-fund >"$INSTALL_LOG" 2>&1 || (tail -n 200 "$INSTALL_LOG" >&2; echo "npm i failed on first attempt, retrying" >&2; npm i --no-audit --no-fund >"$INSTALL_LOG" 2>&1 || (tail -n 200 "$INSTALL_LOG" >&2; exit 8))
fi
# Verify local binaries
TSC=./node_modules/.bin/tsc
MOCHA=./node_modules/.bin/mocha
VSCE=./node_modules/.bin/vsce
[ -x "$TSC" ] || { echo "ERROR: local tsc missing" >&2; exit 9; }
# vsce may not be executable in some npm layouts; warn if missing
if [ -x "$VSCE" ]; then "$VSCE" --version || true; else echo "WARNING: local vsce missing; packaging will fallback to npx --yes vsce" >&2; fi
[ -d node_modules/@vscode/test-electron ] || { echo "ERROR: @vscode/test-electron not installed" >&2; exit 10; }
# Compatibility checks and warnings
node -e "const p=require('./package.json'); if(p.engines && p.engines.vscode && p.devDependencies && p.devDependencies.vscode){if(p.engines.vscode!==p.devDependencies.vscode)console.warn('WARNING: engines.vscode='+p.engines.vscode+' differs from devDependency vscode='+p.devDependencies.vscode);}"
NODE_MAJOR=$(node -e "console.log(process.versions.node.split('.')[0])")
if [ "$NODE_MAJOR" -lt 20 ]; then echo "NOTE: using @types/node ^18 to match Node ${NODE_MAJOR} runtime"; fi
exit 0
