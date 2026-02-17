# OpenClaw Fresh Start - Complete Removal and Reinstall Guide

## Environment

- **VM**: openclaw-vm (Ubuntu Server 24.04 LTS on Hyper-V)
- **Dev Laptop**: coderlt (Ubuntu)
- **Installed Version**: OpenClaw v2026.2.16 (commit aa22042)
- **Tailscale**: Configured with Tailscale Serve at https://openclaw-vm.tail97564d.ts.net
- **Tailscale IP**: 100.123.215.19
- **Fork**: https://github.com/prillcode/openclaw (upstream: https://github.com/openclaw/openclaw)

## Previously Encountered Issues (May Be Fixed in v2026.2.16)

- Web dashboard authentication broken (device identity required error in v2.13-2.15)
- Discord ByteString encoding error when using @ mentions

## Deployment Philosophy

- **Dev laptop**: Source code, git, building
- **VM**: Clean - only the globally installed package, no source code
- **Deployment**: Build on VM via GitHub clone script, or build locally and SCP tarball

---

## Step 1: Complete Removal

```bash
# Stop the gateway service
systemctl --user stop openclaw-gateway.service

# Disable the service
systemctl --user disable openclaw-gateway.service

# Remove the pnpm global package
pnpm remove -g openclaw

# Remove ALL OpenClaw config and data (NUCLEAR OPTION)
rm -rf ~/.openclaw
rm -rf ~/.config/systemd/user/openclaw-gateway.service

# Clean pnpm cache (optional but thorough)
pnpm store prune

# Verify nothing is listening on port 18789
sudo ss -tlnp | grep 18789
```

## Step 2: Development Setup with Your Fork

### Why Use Your Fork (prillcode/openclaw)?

**Benefits:**

- Make custom patches for bugs you're hitting (device auth, Discord ByteString)
- Track your own fixes and modifications
- Contribute PRs back to openclaw/openclaw if you solve something
- Experiment without affecting the official repo
- Easy to sync with upstream when official fixes are released
- Build and test locally before deploying to VM

### Setup on Development Laptop

```bash
# Clone YOUR fork (on your development laptop, NOT the VM)
cd ~/dev  # or wherever you keep projects
git clone https://github.com/prillcode/openclaw.git
cd openclaw

# Add official repo as upstream (for pulling in updates)
git remote add upstream https://github.com/openclaw/openclaw.git

# Verify remotes
git remote -v
# Should show:
# origin    https://github.com/prillcode/openclaw.git (fetch)
# origin    https://github.com/prillcode/openclaw.git (push)
# upstream  https://github.com/openclaw/openclaw.git (fetch)
# upstream  https://github.com/openclaw/openclaw.git (push)

# Install dependencies
pnpm install

# Build the UI (auto-installs UI deps on first run)
pnpm ui:build

# Build the project
pnpm build

# Check version
grep '"version"' package.json
# Should show: "version": "2026.2.16" (or higher)
```

### Syncing with Upstream (Official Repo)

When official bug fixes are released or you want to pull in updates:

```bash
cd ~/dev/openclaw

# Fetch latest changes from official repo
git fetch upstream

# Merge official changes into your fork
git merge upstream/main

# Or use rebase for cleaner history (if you haven't pushed your changes yet)
git rebase upstream/main

# If you have conflicts, resolve them, then:
git add .
git rebase --continue  # (if using rebase)
# or
git commit  # (if using merge)

# Rebuild after pulling updates
pnpm install
pnpm ui:build
pnpm build

# Push updates to your fork
git push origin main
```

### Making Your Own Fixes

```bash
# Create a branch for your fix
git checkout -b fix/device-auth-bug

# Make your changes, test them
# ...

# Commit your changes
git add .
git commit -m "Fix: Device authentication bypass not working"

# Rebuild
pnpm build

# Push to your fork
git push origin fix/device-auth-bug

# If your fix works, you can optionally create a PR to openclaw/openclaw
# Or just keep it in your fork and merge to your main branch
git checkout main
git merge fix/device-auth-bug
```

### Deployment Workflow: GitHub Clone Script on VM (RECOMMENDED)

**Philosophy:** Keep the VM clean - no permanent source code. Build on VM from GitHub, install globally, then clean up.

#### One-Time Setup: Create Deploy Script on VM

```bash
ssh prill@openclaw-vm

cat > ~/deploy-from-github.sh << 'EOF'
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
EOF

chmod +x ~/deploy-from-github.sh
```

#### Deploy / Update to Latest

```bash
# SSH to VM and run the script
ssh prill@openclaw-vm
./deploy-from-github.sh
```

**What this does:**

1. Clones your fork from GitHub (shallow clone for speed)
2. Installs all dependencies including devDependencies (required for build)
3. Builds the UI and project
4. Packs into versioned tarball (e.g. `openclaw-2026.2.16.tgz`)
5. Installs globally to pnpm using full path (avoids SSH env issues)
6. Cleans up - no source code left on VM

#### Full Update Workflow

```bash
# On dev laptop - pull latest upstream and push to your fork
cd ~/dev/openclaw
git fetch upstream
git merge upstream/main
git push origin main

# On VM - deploy the latest
ssh prill@openclaw-vm
./deploy-from-github.sh
```

#### Important Build Notes

- **Must use `pnpm install` (not `--prod`)** - devDependencies are required for the canvas A2UI build step
- **Must use full path for global install** - `pnpm add -g --force "$TARBALL"` not `./openclaw-*.tgz`
- The "Ignored build scripts" warning is normal - run `pnpm approve-builds -g` after install

## Step 3: Deploy to VM and Run Onboarding

```bash
# SSH to VM and run the deploy script
ssh prill@openclaw-vm
./deploy-from-github.sh

# Verify installation
openclaw --version
# Should show: 2026.2.16 (or higher)

# Approve build scripts (one-time after fresh install)
pnpm approve-builds -g

# Run onboarding wizard
openclaw onboard --install-daemon
```

### Onboarding Selections (for reference):

1. **Model Provider**: Choose your AI provider (e.g., Anthropic, OpenAI, or ZAI as you had before)
2. **Gateway Settings**:
   - Bind: `loopback` (127.0.0.1)
   - Tailscale mode: `serve`
   - Auth mode: `token` (or try without device auth if possible)
3. **Discord Configuration**:
   - Token: Your existing Discord bot token
   - Channels: Configure your channels by name or ID
   - Consider using numeric channel IDs instead of names for better reliability
4. **Skills**: Select skills as needed

### Important Onboarding Notes:

- When configuring Tailscale Serve, it should automatically configure: `sudo tailscale serve --bg http://127.0.0.1:18789`
- Ensure Tailscale operator permissions are set: `sudo tailscale set --operator=prill`
- Add trusted proxies for Tailscale: `gateway.trustedProxies: ["127.0.0.1", "::1"]`

## Step 4: Post-Installation Configuration (OPTIONAL - Only if Issues Persist)

**Note:** Version 2026.2.16 includes many fixes and may have resolved the device auth and web UI issues. **Try accessing the web dashboard first before applying these workarounds.**

If you still encounter the "device identity required" error or other authentication issues, apply these settings:

```bash
# Configure trusted proxies for Tailscale Serve
openclaw config set gateway.trustedProxies '["127.0.0.1","::1"]'

# Enable Tailscale authentication (bypasses device token issues)
openclaw config set gateway.auth.allowTailscale true

# Allow insecure auth (helps with device pairing issues)
openclaw config set gateway.controlUi.allowInsecureAuth true

# Restart the gateway
systemctl --user restart openclaw-gateway.service
```

**These were workarounds for bugs in v2026.2.13-2.15. They may not be needed anymore!**

## Step 5: Verify Installation

```bash
# Check service status
systemctl --user status openclaw-gateway.service

# Check logs
journalctl --user -u openclaw-gateway.service -f

# Verify Tailscale Serve is configured
tailscale serve status

# Check OpenClaw version
openclaw --version

# Run doctor to check health
openclaw doctor
```

## Step 6: Test Access and Device Pairing

### The Pairing Flow (New in v2026.2.16)

The web UI now uses a **device pairing** system instead of the old broken device identity. Here's how it works:

1. Open the web UI in your browser - you'll see `disconnected (1008): pairing required`
2. This registers a pending pairing request on the gateway
3. Approve it from the CLI on the VM
4. Browser connects automatically

### Step-by-Step:

**1. Open web UI in browser:**

```
https://openclaw-vm.tail97564d.ts.net/
```

You'll see "pairing required" - that's expected!

**2. Check pending pairing requests on VM:**

```bash
openclaw devices list
```

You'll see something like:

```
Pending (1)
┌──────────────────────────────────────┬──────────────────────┬──────────┬───────┐
│ Request                              │ Device               │ Role     │ Age   │
├──────────────────────────────────────┼──────────────────────┼──────────┼───────┤
│ e7ae131e-d7fd-4395-a7f3-b6dbd28f11e2 │ 4f423014ef74c4cbd7.. │ operator │ 1m ago│
└──────────────────────────────────────┴──────────────────────┴──────────┴───────┘
```

**3. Approve the most recent request:**

```bash
openclaw devices approve e7ae131e-d7fd-4395-a7f3-b6dbd28f11e2
# (use your actual Request ID)
```

**4. Refresh browser → Dashboard loads! 🎉**

### Expected Result After Pairing:

- ✅ STATUS: OK (green)
- ✅ Gateway connected via `wss://openclaw-vm.tail97564d.ts.net`
- ✅ Full dashboard sidebar visible
- ✅ Uptime counter running

### Tips:

- Each new browser/device needs its own pairing approval
- Use InPrivate/Incognito windows to test fresh pairing
- Multiple pending requests may appear if you tried multiple times - approve the most recent one
- Paired devices persist across gateway restarts

### Option 2: Web Dashboard via SSH Tunnel (from laptop)

```bash
ssh -L 18789:127.0.0.1:18789 prill@openclaw-vm
```

Then open: `http://localhost:18789/` and follow the same pairing flow.

### Option 3: Discord

- Send messages in configured channels (#family-assistant, #devwork-assistant, etc.)
- Test both with and without @ mentions
- Check if ByteString encoding error still occurs

---

## Deployment Workflow Summary

**GitHub Script (Settled Approach):**

1. Push latest changes from dev laptop to `prillcode/openclaw` on GitHub
2. SSH to VM and run `./deploy-from-github.sh`
3. Script clones, builds, installs globally, and cleans up automatically

**Why not SCP tarball directly from laptop?**

- SSH non-interactive shells don't load `.bashrc`, so `$PNPM_HOME` isn't set
- The `bash -l -c` and `source ~/.bashrc` workarounds both fail due to early exit for non-interactive shells
- GitHub script approach sidesteps this entirely by running interactively on the VM

**Command locations:**

- **On VM**: `openclaw <command>` (globally installed)
- **Dev laptop**: Source code, git operations, pushing to fork
- **Updates**: `git push origin main` on laptop → `./deploy-from-github.sh` on VM

---

## Known Issues / Notes for v2026.2.16

1. **Web UI Pairing**: "pairing required" is NOT a bug - it's the new device pairing flow. See Step 6 for approval process.
2. **Discord ByteString Error**: Was related to Unicode in @ mentions - test if still present
3. **Tailscale Serve Permission**: Still needed: ensure `sudo tailscale set --operator=prill` is run
4. **Message Content Intent**: May still need to be enabled in Discord Developer Portal for the bot to see messages
5. **Z.AI Model Tier**: `zai/glm-5` may require a higher subscription - switch to `zai/glm-4-flash` if you hit rate limit errors:
   ```bash
   openclaw config set agents.defaults.model zai/glm-4-flash
   ```

---

## Quick Reference Commands

### On VM (openclaw-vm):

```bash
./deploy-from-github.sh          # Deploy latest from GitHub fork
openclaw config                  # View/edit config
openclaw config get <key>        # Get specific config value
openclaw config set <key> <value>  # Set config value
openclaw doctor                  # Health check and repairs
openclaw devices list            # List paired devices
openclaw gateway status          # Check gateway status
openclaw --version               # Check version
pnpm approve-builds -g           # Approve native build scripts after install
systemctl --user status openclaw-gateway.service  # Service status
journalctl --user -u openclaw-gateway.service -f   # Watch logs
```

### On Dev Laptop:

```bash
cd ~/dev/openclaw
git fetch upstream               # Get latest from official repo
git merge upstream/main          # Merge updates
git push origin main             # Push to your fork (triggers VM deploy)
```

## Files and Directories

### On Dev Laptop:

- **Your Forked Source Code**: `~/dev/openclaw/` (from https://github.com/prillcode/openclaw)
- **Build artifacts**: `~/dev/openclaw/dist/`
- **Deployment tarballs**: `~/dev/openclaw/openclaw-*.tgz` (temporary, cleaned after deploy)

### On VM (openclaw-vm):

- **Installed Package**: Global pnpm location (run `pnpm root -g` to find)
- **Config**: `~/.openclaw/openclaw.json`
- **Logs**: `/tmp/openclaw/openclaw-YYYY-MM-DD.log`
- **Service File**: `~/.config/systemd/user/openclaw-gateway.service`
- **Credentials**: `~/.openclaw/credentials/`
- **Workspace**: `~/.openclaw/workspace/`

---

## Emergency Rollback

If the deployed version has issues and you want to go back to official pnpm release:

### On VM:

```bash
# Remove custom deployment
pnpm remove -g openclaw

# Install official release
pnpm add -g openclaw@latest
openclaw onboard --install-daemon
```

### On Dev Laptop:

Your fork remains intact at `~/dev/openclaw` - you can continue developing and testing locally.

---

## Status

- ✅ Old pnpm installation removed
- ✅ Config wiped (fresh start)
- ✅ `deploy-from-github.sh` created on VM
- ✅ OpenClaw v2026.2.16 successfully deployed and installed
- ✅ `openclaw onboard --install-daemon` completed
- ✅ Discord bot connected (@Claw)
- ✅ Web UI accessible via Tailscale Serve
- ✅ Device pairing approved - dashboard fully working!
- ⏳ Z.AI model tier issue - may need to switch from glm-5 to glm-4-flash
- ⏳ Test Discord @ mentions (ByteString bug)
