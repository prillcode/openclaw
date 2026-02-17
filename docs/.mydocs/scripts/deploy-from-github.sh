#!/bin/bash
set -e

echo "🦞 Deploying OpenClaw from GitHub..."

# Clean up any previous build
rm -rf /tmp/openclaw-build

# Clone your fork (shallow, only latest commit)
echo "📥 Cloning prillcode/openclaw..."
git clone --depth 1 https://github.com/prillcode/openclaw.git /tmp/openclaw-build

cd /tmp/openclaw-build

# Install ALL dependencies (devDependencies needed for build!)
echo "📦 Installing dependencies..."
pnpm install

# Build UI and project
echo "🔨 Building..."
pnpm ui:build
pnpm build

# Pack and install globally using full path
echo "📦 Creating tarball..."
pnpm pack

echo "🚀 Installing globally..."
TARBALL=$(ls /tmp/openclaw-build/openclaw-*.tgz)
pnpm add -g --force "$TARBALL"

# Approve build scripts
pnpm approve-builds -g

# Clean up build artifacts
cd ~
rm -rf /tmp/openclaw-build

echo "✅ Deployment complete!"
echo "Run 'openclaw doctor' to verify"
