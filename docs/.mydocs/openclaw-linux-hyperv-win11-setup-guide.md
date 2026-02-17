# Setting up OpenClaw on Linux Ubuntu Latest via Windows 11 Pro Hyper-V

This guide walks through creating a Ubuntu Server 24.04 LTS virtual machine in Windows 11 Hyper-V and installing OpenClaw, a personal AI assistant that runs on your own devices.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Download Ubuntu Server ISO](#download-ubuntu-server-iso)
3. [Create Hyper-V Virtual Machine](#create-hyper-v-virtual-machine)
4. [Install Ubuntu Server](#install-ubuntu-server)
5. [Post-Installation System Setup](#post-installation-system-setup)
6. [Install Tailscale](#install-tailscale)
7. [Install OpenClaw](#install-openclaw)
8. [Access OpenClaw Dashboard](#access-openclaw-dashboard)
9. [Managing Checkpoints](#managing-checkpoints)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

- Windows 11 Pro with Hyper-V enabled
- At least 8GB RAM available for the VM
- At least 50GB free disk space
- Stable internet connection
- Anthropic API key (for Claude access) or other AI provider credentials
- Tailscale account (for homelab network access)

---

## Download Ubuntu Server ISO

1. Visit https://ubuntu.com/download/server
2. Download **Ubuntu Server 24.04 LTS** (latest LTS version)
3. Save the ISO file to a known location (e.g., `C:\ISOs\ubuntu-24.04-server.iso`)

---

## Create Hyper-V Virtual Machine

### 1. Open Hyper-V Manager

- Press `Win + S` and search for "Hyper-V Manager"
- Or navigate to: Start → Windows Administrative Tools → Hyper-V Manager

### 2. Create New Virtual Machine

1. In Hyper-V Manager, click **"New" → "Virtual Machine"** (not Quick Create)
2. Click **"Next"** on the wizard welcome screen

### 3. Specify Name and Location

- **Name**: `openclaw-vm`
- Optionally change the storage location
- Click **"Next"**

### 4. Specify Generation

- Select **"Generation 2"** (recommended for modern Linux)
- Click **"Next"**

### 5. Assign Memory

- **Startup memory**: `8192 MB` (8GB recommended)
- **Minimum**: 4096 MB (4GB) will work, but 8GB provides better performance
- Check **"Use Dynamic Memory"** (optional, helps with resource management)
- Click **"Next"**

### 6. Configure Networking

- Select your network adapter:
  - **Default Switch** (simplest option)
  - Or select an existing virtual switch
- Click **"Next"**

### 7. Connect Virtual Hard Disk

- Select **"Create a virtual hard disk"**
- **Name**: `openclaw-vm.vhdx`
- **Location**: Accept default or choose custom location
- **Size**: `50 GB` minimum (100GB recommended for larger deployments)
- Click **"Next"**

### 8. Installation Options

- Select **"Install an operating system from a bootable image file"**
- Click **"Browse"** and select your Ubuntu Server ISO file
- Click **"Next"**

### 9. Complete the Wizard

- Review your settings
- Click **"Finish"**

### 10. Configure VM Settings (IMPORTANT for Gen 2 VMs)

Before starting the VM:

1. Right-click the VM → **Settings**
2. Navigate to **Security**:
   - **Uncheck "Enable Secure Boot"**
   - OR change template to **"Microsoft UEFI Certificate Authority"**
3. Navigate to **Firmware**:
   - Ensure **DVD Drive** is listed **above** Hard Drive in boot order
   - Use arrows to reorder if needed
4. **Optional but Recommended**: Navigate to **Management** → **Checkpoints**:
   - Check **"Enable checkpoints"**
   - Select **"Production checkpoints"** (recommended for best application consistency)
5. Click **"OK"** to save settings

---

## Install Ubuntu Server

### Start the Virtual Machine

1. Right-click the VM → **"Connect"**
2. Click **"Start"** button in the console window
3. Ubuntu installer should boot from the ISO

### Ubuntu Installation Steps

Follow the Ubuntu Server installer:

1. **Language**: Select your language (English)
2. **Keyboard**: Select your keyboard layout
3. **Installation type**: Choose **"Ubuntu Server"**
4. **Network**: Configure network (should auto-detect DHCP)
5. **Proxy**: Leave blank unless you need a proxy
6. **Mirror**: Accept default Ubuntu archive mirror
7. **Storage**:
   - Select **"Use an entire disk"**
   - Select the virtual disk
   - Confirm storage layout
8. **Profile setup**:
   - **Your name**: Enter your name
   - **Server name**: `openclaw-vm` (or preferred hostname)
   - **Username**: Your username (e.g., `aaron`)
   - **Password**: Create a secure password
9. **SSH Setup**:
   - Check **"Install OpenSSH server"** (recommended)
   - **Important**: You can skip the "Import SSH key" section entirely
   - **Why?** Since you'll be using Tailscale SSH (configured later), traditional SSH keys are redundant
   - Password authentication is fine to leave enabled as a backup method
   - Tailscale SSH will handle authentication via your Tailscale identity (Google, GitHub, etc.)
   - You'll have three access methods:
     - **Tailscale SSH** (primary): `ssh openclaw-vm` from any device on your tailnet
     - **Password authentication** (backup): Direct SSH if Tailscale has issues
     - **Hyper-V Console** (emergency): Always available directly in Hyper-V Manager
10. **Featured Server Snaps**:
    - Skip (press **"Done"** without selecting anything)
11. **Installation**: Wait for installation to complete
12. **Reboot**: Select **"Reboot Now"** when prompted
13. **Remove ISO**: You may see "Please remove installation medium" - in Hyper-V console menu, go to Media → DVD Drive → Eject

### First Login

- Login with your username and password
- You should now be at the Ubuntu command prompt

### Optional: Create Checkpoint - "Fresh Ubuntu Install"

This checkpoint allows you to roll back to a clean Ubuntu installation if needed:

1. In Hyper-V Manager, right-click your **openclaw-vm** VM
2. Select **Checkpoint**
3. A checkpoint will be created with a timestamp name
4. Right-click the newly created checkpoint and select **Rename**
5. Name it: `Fresh Ubuntu Install`

This gives you a restore point before making any system changes.

---

## Post-Installation System Setup

**Note**: From here forward, if you prefer using your own terminal instead of the Hyper-V console, you can SSH into the VM:

1. In the Hyper-V console, get the VM's local IP address:
   ```bash
   hostname -I
   ```
2. From your Windows machine (or another computer on the same network), SSH in:
   ```bash
   ssh username@<local-ip>
   # Example: ssh aaron@192.168.1.45
   ```
3. After Tailscale is installed later, you can use the simpler hostname:
   ```bash
   ssh openclaw-vm
   ```

---

### Update System Packages

```bash
sudo apt update && sudo apt upgrade -y
```

### Optional: Create Checkpoint - "System Updated"

After system updates complete:

1. In Hyper-V Manager, right-click **openclaw-vm**
2. Select **Checkpoint**
3. Right-click the newly created checkpoint and select **Rename**
4. Name it: `System Updated`

This checkpoint captures your VM with all latest security patches.

### Install Essential Tools

```bash
sudo apt install -y curl git build-essential
```

### Install Node.js (Required for OpenClaw)

```bash
# Install Node.js 22.x (current LTS)
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs

# Verify installation
node --version
npm --version
```

Expected output: Node.js v22.x.x and npm 10.x.x or higher

### Install pnpm (Recommended by OpenClaw)

```bash
sudo npm install -g pnpm

# Verify installation
pnpm --version

# Setup pnpm (required if pnpm hasn't been previously setup on the VM)
pnpm setup

# Source your shell configuration to apply changes
source ~/.bashrc
```

**Note**: The `pnpm setup` command configures pnpm's global bin directory and adds it to your PATH. You'll need to reload your shell configuration or log out and back in for the changes to take effect.

### Optional: Add Swap Space (Recommended)

Even with 8GB RAM, adding swap is good practice for build processes and prevents out-of-memory errors:

```bash
# Create 4GB swap file
sudo fallocate -l 4G /swapfile

# Set correct permissions
sudo chmod 600 /swapfile

# Set up swap
sudo mkswap /swapfile

# Enable swap
sudo swapon /swapfile

# Make swap permanent (persists across reboots)
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Verify swap is active
free -h
```

---

## Install Tailscale

Tailscale allows you to access your OpenClaw VM from anywhere on your homelab network.

### Install Tailscale

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
```

### Connect to Your Tailnet

```bash
# Authenticate and connect (with custom hostname)
sudo tailscale up --hostname=openclaw-vm
```

This will output a URL like: `https://login.tailscale.com/a/...`

1. Copy the URL and paste it into your browser
2. Log in to your Tailscale account
3. Approve the device

### Verify Tailscale Connection

```bash
# Check Tailscale status
tailscale status

# Get your Tailscale IP address
tailscale ip -4
```

Save this IP address - you'll use it to access OpenClaw's web interface.

### Optional: Enable Tailscale SSH

**Important**: Tailscale requires you to specify ALL non-default flags each time you run `tailscale up`. Since you already set `--hostname` during initial connection, you must include it again.

```bash
# Enable SSH over Tailscale (recommended)
sudo tailscale up --hostname=openclaw-vm --ssh
```

This enables SSH access from any device on your Tailscale network using just the hostname: `ssh openclaw-vm`

---

## Optional: Create Checkpoint - "Dependencies Installed"

Before installing OpenClaw, create a checkpoint with all prerequisites in place:

1. In Hyper-V Manager, right-click **openclaw-vm**
2. Select **Checkpoint**
3. Right-click the newly created checkpoint and select **Rename**
4. Name it: `Dependencies Installed`

This checkpoint captures your VM with Node.js, pnpm, and Tailscale ready to go.

---

## Install OpenClaw

Since we've already installed pnpm, we'll use it to install OpenClaw globally.

### Install OpenClaw via pnpm

```bash
pnpm add -g openclaw@latest
```

**Note**: No `sudo` needed - pnpm installs to a user-level global directory configured by `pnpm setup`.

This installs the latest version of OpenClaw globally on your system.

### Approve Build Scripts

pnpm requires explicit approval for packages with build scripts (for security). After installation, you'll see a warning about ignored build scripts. Approve them:

```bash
pnpm approve-builds -g
```

Select all the packages listed (sharp, node-llama-cpp, protobufjs, etc.) to allow their build scripts to run. These are legitimate OpenClaw dependencies that need to compile native code.

### Run the Onboarding Wizard

```bash
openclaw onboard --install-daemon
```

**Note**: If you encounter a "JavaScript heap out of memory" error during onboarding (especially when adding channels like Discord), exit and restart with increased heap size:

```bash
export NODE_OPTIONS="--max-old-space-size=4096"
openclaw onboard --install-daemon
```

The wizard will guide you through:

1. **Gateway Configuration**:
   - Port selection (default: 18789 is fine)
   - Bind address: Select **"Tailnet (Tailscale IP)"** to make the gateway accessible via your Tailscale network
   - Gateway auth: Select **"Token"** (requires authentication token to access dashboard)
   - Tailscale exposure:
     - **"Off"** - Access via `http://<tailscale-ip>:18789` (simple and secure)
     - **"Serve"** - Access via `https://openclaw-vm.tail<xyz>.ts.net` (nicer URL with HTTPS, still private to tailnet)
     - **"Funnel"** - Exposes to public internet (NOT recommended for homelab use)

2. **AI Provider Setup**:
   - Select provider (Anthropic/Claude recommended)
   - Enter your API key
   - Choose default model (Claude Sonnet 4.5 recommended)

3. **Channel Configuration**:
   - Choose messaging platforms (Discord, Telegram, WhatsApp, Slack, etc.)
   - Follow platform-specific setup instructions
   - Configure channel settings

4. **Skills Installation**:
   - Select optional skills to install
   - Browser automation, security tools, etc.

5. **Daemon Installation**:
   - Installs OpenClaw as a systemd service
   - Enables automatic startup on boot

### Verify Installation

```bash
# Check if OpenClaw service is running
sudo systemctl status openclaw

# View OpenClaw logs
sudo journalctl -u openclaw -f

# Or view logs from OpenClaw CLI
openclaw logs
```

### Optional: Create Checkpoint - "OpenClaw Working"

Once OpenClaw is installed and running successfully, create a checkpoint:

1. In Hyper-V Manager, right-click **openclaw-vm**
2. Select **Checkpoint**
3. Right-click the newly created checkpoint and select **Rename**
4. Name it: `OpenClaw Working`

This is your most important checkpoint - a known-good state you can always return to.

---

## Access OpenClaw Dashboard

### Get Access URL

Your access URL depends on the Tailscale exposure option you selected during setup:

**If you selected "Serve":**

```bash
# Your access URL will be shown at the end of the onboarding wizard
# It will look like: https://openclaw-vm.tail<xyz>.ts.net
```

**If you selected "Off":**

```bash
# Get your Tailscale IP
tailscale ip -4

# Your access URL will be: http://<tailscale-ip>:18789
```

Example: `http://100.64.0.5:18789` or `https://openclaw-vm.tail1234.ts.net`

### Open Dashboard

1. From any device on your Tailscale network (laptop, phone, etc.)
2. Open a web browser
3. Navigate to: `http://<tailscale-ip>:18789`
4. You should see the OpenClaw control interface

### Get Dashboard Token (if needed)

If the dashboard asks for an authentication token:

```bash
# Display the dashboard token
openclaw dashboard
```

### Useful OpenClaw Commands

```bash
# Check OpenClaw status
openclaw status

# Run diagnostics
openclaw doctor

# View configuration
openclaw config

# Restart the gateway
sudo systemctl restart openclaw

# View live logs
openclaw logs --follow

# Update OpenClaw to latest version
openclaw update
```

---

## Managing Checkpoints

If you enabled checkpoints during VM setup, here's how to use them effectively:

### Viewing Checkpoints

1. In Hyper-V Manager, select your **openclaw-vm**
2. Look at the **Checkpoints** pane (usually bottom middle)
3. You'll see a tree of all checkpoints with timestamps

### Applying a Checkpoint (Rollback)

To restore your VM to a previous checkpoint:

1. **Shut down the VM** (recommended, though not always required)
2. Right-click the checkpoint you want to restore
3. Select **Apply...**
4. Choose one of:
   - **Create Checkpoint** - saves current state before applying (recommended)
   - **Apply** - directly applies without saving current state
5. Click **Apply**
6. Start the VM - it will boot in the checkpoint state

### Deleting Checkpoints

To free up disk space:

1. Right-click a checkpoint
2. Select **Delete Checkpoint...**
3. Choose:
   - **Delete Checkpoint** - merges changes into parent, preserves data
   - **Delete Checkpoint Subtree** - deletes this and all child checkpoints
4. Confirm the deletion

**Note**: Deleting checkpoints is permanent and cannot be undone.

### Best Practices

- **Create checkpoints before major changes**: Updates, new skills, config changes
- **Rename for clarity**: Hyper-V creates checkpoints with timestamps - right-click and rename them to descriptive names like "Before Update 2026-02-16" or "Fresh Ubuntu Install"
- **Don't keep too many**: Delete old checkpoints once newer stable ones exist
- **Test after applying**: Always verify the system works after restoring a checkpoint

---

## Troubleshooting

### VM Won't Boot / Stuck at Boot Screen

- **Issue**: Generation 2 VM won't boot from ISO
- **Solution**:
  1. Shutdown VM
  2. VM Settings → Security → Disable Secure Boot
  3. VM Settings → Firmware → Ensure DVD is first in boot order

### Out of Memory During Installation

- **Issue**: Installation fails with `JavaScript heap out of memory`
- **Solution**:
  1. Add swap space (see Post-Installation Setup)
  2. Or increase Node memory limit:
     ```bash
     export NODE_OPTIONS="--max-old-space-size=3072"
     pnpm add -g openclaw@latest
     ```

### Out of Memory During Onboarding

- **Issue**: Onboarding wizard crashes with `FATAL ERROR: Reached heap limit Allocation failed - JavaScript heap out of memory`
- **Solution**:
  1. Exit the wizard (Ctrl+C)
  2. Increase Node.js heap size and restart:
     ```bash
     export NODE_OPTIONS="--max-old-space-size=4096"
     openclaw onboard --install-daemon
     ```
  3. The wizard will resume from where you left off or restart the setup

### OpenClaw Command Not Found

- **Issue**: After installation, `openclaw` command not found
- **Solution**:
  1. Close and reopen your terminal (or SSH session)
  2. If still not found, check npm global bin path:
     ```bash
     npm config get prefix
     # Add the bin directory to PATH if needed
     echo 'export PATH="$(npm prefix -g)/bin:$PATH"' >> ~/.bashrc
     source ~/.bashrc
     ```

### pnpm Global Bin Directory Error

- **Issue**: `ERR_PNPM_NO_GLOBAL_BIN_DIR Unable to find the global bin directory`
- **Solution**: Run pnpm setup (this is required for first-time pnpm usage):
  ```bash
  pnpm setup
  source ~/.bashrc
  # Then retry the installation
  pnpm add -g openclaw@latest
  ```

### Can't Access OpenClaw Dashboard

- **Issue**: Cannot reach dashboard at `http://<tailscale-ip>:18789`
- **Solution**:
  1. Verify OpenClaw is running: `sudo systemctl status openclaw`
  2. Check Tailscale connection: `tailscale status`
  3. Verify gateway is bound to LAN interface:
     ```bash
     openclaw config
     # Look for "bind": "lan" or "bind": "0.0.0.0"
     ```
  4. Check if port 18789 is listening:
     ```bash
     sudo ss -tlnp | grep 18789
     ```

### Tailscale Connection Issues

- **Issue**: Can't connect to Tailscale network
- **Solution**:
  1. Check if Tailscale is running: `sudo systemctl status tailscaled`
  2. Restart Tailscale: `sudo systemctl restart tailscaled`
  3. Re-authenticate: `sudo tailscale up`
  4. Check firewall: Ubuntu Server typically has no firewall enabled by default

### OpenClaw Service Won't Start

- **Issue**: `sudo systemctl status openclaw` shows failed
- **Solution**:
  1. Check logs: `sudo journalctl -u openclaw -n 50`
  2. Verify API keys are set: `openclaw config`
  3. Try running manually to see errors: `openclaw gateway`
  4. Restart the service: `sudo systemctl restart openclaw`

### Channel Connection Issues

- **Issue**: Discord/Telegram/Slack not connecting
- **Solution**:
  1. Verify API tokens/credentials: `openclaw config`
  2. Check channel-specific logs: `openclaw logs`
  3. Run diagnostics: `openclaw doctor`
  4. Re-run channel setup: `openclaw channel setup <platform>`

### Port Already in Use

- **Issue**: Port 18789 already in use
- **Solution**:
  1. Find what's using the port: `sudo lsof -i :18789`
  2. Kill the process or change OpenClaw port:
     ```bash
     openclaw config set gateway.port 18790
     sudo systemctl restart openclaw
     ```

---

## Additional Resources

- **OpenClaw GitHub**: https://github.com/openclaw/openclaw
- **OpenClaw Documentation**: https://openclaw.ai/docs
- **OpenClaw Discord**: Join for community support
- **Security Best Practices**: https://openclaw.ai/docs/security
- **Tailscale Documentation**: https://tailscale.com/kb

---

## Security Considerations

1. **Keep OpenClaw Updated**: Run `openclaw update` regularly
2. **Secure Your API Keys**: Never commit API keys to git or share them
3. **Review Skills Before Installing**: Use `openclaw doctor` to check for security issues
4. **Use Strong Tailscale Authentication**: Enable 2FA on your Tailscale account
5. **Monitor Logs**: Regularly check `openclaw logs` for suspicious activity
6. **DM Policy**: Configure strict DM policies to prevent unauthorized access:
   ```bash
   # Use pairing mode for DMs (recommended)
   openclaw config set channels.discord.dmPolicy pairing
   ```

---

## Next Steps

1. **Configure Channels**: Set up Discord, Telegram, or other messaging platforms
2. **Install Skills**: Browse and install useful OpenClaw skills
3. **Create Agents**: Set up multiple agents with different personalities/capabilities
4. **Customize SOUL.md**: Define your assistant's personality and behavior
5. **Explore Advanced Features**: Voice mode, multi-agent routing, custom tools

---

**Document Version**: 1.0  
**Last Updated**: February 2026  
**OpenClaw Version**: Latest stable release  
**Ubuntu Version**: 24.04 LTS
