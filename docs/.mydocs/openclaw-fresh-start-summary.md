# OpenClaw Fresh Start - Complete Removal and Source Installation

## Current Situation

- **VM**: openclaw-vm (Ubuntu Server 24.04 LTS on Hyper-V)
- **Current Installation**: OpenClaw v2026.2.13 installed via `pnpm add -g openclaw@latest`
- **Issues Encountered**:
  - Web dashboard authentication broken (device identity required error persists across versions 2.13 and 2.15, v2.4 doesn't exist)
  - Discord ByteString encoding error when using @ mentions
- **Tailscale**: Configured with Tailscale Serve at https://openclaw-vm.tail97564d.ts.net
- **Tailscale IP**: 100.123.215.19

## Goal

Remove pnpm-based installation completely, clean all config/settings, clone the repo, build from source, and re-run onboarding.

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

### Deployment Workflow: Build Locally, Deploy to VM

**Philosophy:** Keep the VM clean - no source code, no build tools, just the packaged application.

#### One-Time Setup: Create Deployment Alias

Add this to `~/.bashrc` or `~/.zshrc` on your **development laptop**:

```bash
echo '
alias deploy-openclaw="
  cd ~/dev/openclaw && \
  rm -f openclaw-*.tgz && \
  pnpm pack && \
  TARBALL=\$(ls openclaw-*.tgz) && \
  echo \"📦 Deploying \$TARBALL to openclaw-vm...\" && \
  scp \$TARBALL prill@openclaw-vm:~/ && \
  ssh prill@openclaw-vm \"pnpm add -g --force ~/\$TARBALL && openclaw doctor && rm ~/\$TARBALL\" && \
  rm \$TARBALL && \
  echo \"✅ Deployment complete!\"
"
' >> ~/.bashrc

source ~/.bashrc
```

**What this does:**

1. Packages your built code into `openclaw-<version>.tgz`
2. SCPs it to the VM
3. Installs it globally on the VM via pnpm
4. Runs health check (`openclaw doctor`)
5. Cleans up tarball on both laptop and VM

#### Deploy to VM

```bash
# On dev laptop - after any changes or upstream sync
cd ~/dev/openclaw

# Build everything
pnpm install
pnpm ui:build
pnpm build

# Deploy to VM with one command
deploy-openclaw
```

The tarball will be named with the version from `package.json` (e.g., `openclaw-2026.2.16.tgz`)

## Step 3: Deploy to VM and Run Onboarding

```bash
# On dev laptop - deploy the built package
deploy-openclaw

# SSH to VM
ssh prill@openclaw-vm

# Verify installation
openclaw --version
# Should show: 2026.2.16 (or higher)

# Run onboarding wizard with daemon installation
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

## Step 6: Test Access (Critical - Test BEFORE Applying Workarounds!)

**🎯 IMPORTANT:** Test the web UI FIRST to see if v2026.2.16 fixed the device auth bug. If it works without extra config, you're golden! 🦞

### Option 1: Web Dashboard via Tailscale (Recommended First Test)

```
https://openclaw-vm.tail97564d.ts.net/
```

**Expected Result:**

- ✅ **If it works**: The bugs are FIXED! No need for Step 4 workarounds!
- ❌ **If you get "device identity required"**: Apply optional Step 4 configuration

### Option 2: Web Dashboard via SSH Tunnel (from laptop)

```bash
ssh -L 18789:127.0.0.1:18789 prill@100.123.215.19
```

Then open: `http://localhost:18789/`

### Option 3: Discord

- Send messages in configured channels (#family-assistant, #devwork-assistant, etc.)
- Test both with and without @ mentions
- Check if ByteString encoding error still occurs

---

## Key Differences: Tarball Deployment vs pnpm Global

**Tarball Deployment Benefits** (Current Workflow):

- Latest code from your fork with upstream fixes
- Clean VM (no source code, no build dependencies)
- Full control over what version gets deployed
- Easy to test changes locally before deploying
- Can apply custom patches and fixes
- Uses `openclaw <command>` (globally installed via pnpm)

**Command Differences**:

- **On VM**: `openclaw <command>` (globally installed from tarball)
- **On dev laptop**: Build and deploy via `deploy-openclaw` alias
- No need to navigate to source directory on VM

**Development Workflow**:

1. Make changes on dev laptop in `~/dev/openclaw`
2. Build: `pnpm install && pnpm ui:build && pnpm build`
3. Deploy: `deploy-openclaw` (packages, uploads, installs on VM)
4. Test on VM via web UI or Discord

---

## Known Issues to Watch For (May Be Fixed in v2026.2.16+)

**Test First - These issues existed in v2026.2.13-2.15 but may be resolved:**

1. **Device Identity Required**: This bug existed across v2.13-2.15. Check if web UI works without extra config!
2. **Discord ByteString Error**: Was related to Unicode in @ mentions - test if still present
3. **Tailscale Serve Permission**: Still needed: ensure `sudo tailscale set --operator=prill` is run
4. **Message Content Intent**: May still need to be enabled in Discord Developer Portal for the bot to see messages

**If any issues persist, apply the optional configuration from Step 4.**

---

## Quick Reference Commands

### On VM (openclaw-vm):

```bash
openclaw config                  # View/edit config
openclaw config get <key>        # Get specific config value
openclaw config set <key> <value>  # Set config value
openclaw doctor                  # Health check and repairs
openclaw devices list            # List paired devices
openclaw gateway status          # Check gateway status
openclaw --version               # Check version
systemctl --user status openclaw-gateway.service  # Service status
journalctl --user -u openclaw-gateway.service -f   # Watch logs
```

### On Dev Laptop:

```bash
cd ~/dev/openclaw
git fetch upstream               # Get latest from official repo
git merge upstream/main          # Merge updates
pnpm install && pnpm ui:build && pnpm build  # Rebuild
deploy-openclaw                  # Deploy to VM
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

## Next Steps in New Chat

1. Upload the "openclaw-hyperv-setup-guide.md" as reference
2. Upload this summary document
3. Execute the removal steps
4. Clone repo and build from source
5. Run onboarding with careful attention to configuration
6. Test both web UI and Discord access
