#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/hello-world-extension-2334-2350/vscode_extension_native"
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"
# Non-destructively create package.json, tsconfig.json, src/extension.ts, and .vscodeignore
if [ ! -f package.json ]; then cat > package.json <<'JSON'
{
  "name": "hello-world-extension",
  "displayName": "Hello World Extension",
  "publisher": "my-publisher",
  "version": "0.0.1",
  "description": "Minimal VSCode extension (TypeScript)",
  "main": "./out/extension.js",
  "engines": { "vscode": "^1.80.0" },
  "repository": { "type": "git", "url": "https://example.com/hello-world-extension.git" },
  "license": "MIT",
  "scripts": {
    "build": "./node_modules/.bin/tsc -p . || npx --yes tsc -p .",
    "package": "./node_modules/.bin/vsce package -o ./out/hello-world-extension-$(node -p \"require('./package.json').version||'0.0.1'\").vsix || npx --yes vsce package -o ./out/hello-world-extension-$(node -p \"require('./package.json').version||'0.0.1'\").vsix",
    "test": "npm run build && ./node_modules/.bin/mocha --reporter spec ./out-test/**/*.js || npx --yes mocha --reporter spec ./out-test/**/*.js"
  },
  "devDependencies": {}
}
JSON
fi
if [ ! -f tsconfig.json ]; then cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "module": "commonjs",
    "target": "es2020",
    "outDir": "out",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "exclude": ["node_modules", ".vscode-test", "out-test"]
}
JSON
fi
mkdir -p src
if [ ! -f src/extension.ts ]; then cat > src/extension.ts <<'TS'
import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
export function activate(context: vscode.ExtensionContext) {
  const disposable = vscode.commands.registerCommand('hello-world.hello', () => {});
  context.subscriptions.push(disposable);
  try {
    const outDir = path.join(context.extensionPath || process.cwd(), 'out');
    fs.mkdirSync(outDir, { recursive: true });
    fs.writeFileSync(path.join(outDir, 'activated.txt'), 'activated');
  } catch (e) {}
}
export function deactivate() {}
TS
fi
if [ ! -f .vscodeignore ]; then cat > .vscodeignore <<'TXT'
node_modules
.vscode
out/test
.vscode-test
out-test
TXT
fi
exit 0
