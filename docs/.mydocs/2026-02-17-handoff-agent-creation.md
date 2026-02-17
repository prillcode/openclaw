# OpenClaw Multi-Agent Handoff

I'm setting up **OpenClaw v2026.2.16** on a homelab VM (Ubuntu 24.04, `openclaw-vm.tail97564d.ts.net`) with multi-agent Discord routing. The service is running fine but I'm stuck on the correct `--bind` syntax for `openclaw agents add`.

## What I'm trying to do

Create 4 agents (Clark, Candace, Cody, Clay), each routing to a specific Discord channel without requiring @mentions.

## The problem

`openclaw agents add --bind discord:default` returns "Unknown channel" - we've tried `discord`, `discord-default`, `discord:default` - all fail.

## Key facts discovered

- `openclaw channels list` shows: `Discord default: configured, token=config, enabled`
- `openclaw channels resolve --channel discord` accepts `discord` as valid channel name
- Channel health JSON shows `accountId: "default"` for the Discord account
- `openclaw agents add --help` shows bind format as `--bind <channel[:accountId]>`
- The `--bind` flag rejects every combination we've tried
- `bindings[].match.channelId` is NOT a valid key - breaks the config entirely

## What I need

1. The correct `--bind` syntax for Discord in `openclaw agents add`
2. OR the correct JSON schema for `bindings[].match` in `openclaw.json`
3. Then a complete updated `openclaw.json` with all 4 agents configured

## Current working openclaw.json

```json
{
  "meta": {
    "lastTouchedVersion": "2026.2.16",
    "lastTouchedAt": "2026-02-17T05:03:56.989Z"
  },
  "wizard": {
    "lastRunAt": "2026-02-17T04:15:31.747Z",
    "lastRunVersion": "2026.2.16",
    "lastRunCommand": "onboard",
    "lastRunMode": "local"
  },
  "auth": {
    "profiles": {
      "zai:default": {
        "provider": "zai",
        "mode": "api_key"
      },
      "deepseek:manual": {
        "provider": "deepseek",
        "mode": "token"
      }
    }
  },
  "models": {
    "mode": "merge",
    "providers": {
      "zai": {
        "baseUrl": "https://api.z.ai/api/coding/paas/v4",
        "api": "openai-completions",
        "models": [
          {
            "id": "glm-5",
            "name": "GLM-5",
            "reasoning": true,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 204800,
            "maxTokens": 131072
          },
          {
            "id": "glm-4.7",
            "name": "GLM-4.7",
            "reasoning": true,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 204800,
            "maxTokens": 131072
          },
          {
            "id": "glm-4.7-flash",
            "name": "GLM-4.7 Flash",
            "reasoning": true,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 204800,
            "maxTokens": 131072
          },
          {
            "id": "glm-4.7-flashx",
            "name": "GLM-4.7 FlashX",
            "reasoning": true,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 204800,
            "maxTokens": 131072
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "zai/glm-4.7-flash"
      },
      "models": {
        "zai/glm-5": {
          "alias": "GLM"
        }
      },
      "workspace": "/home/prill/.openclaw/workspace",
      "compaction": {
        "mode": "safeguard"
      },
      "maxConcurrent": 4,
      "subagents": {
        "maxConcurrent": 8
      }
    }
  },
  "messages": {
    "ackReactionScope": "group-mentions"
  },
  "commands": {
    "native": "auto",
    "nativeSkills": "auto"
  },
  "hooks": {
    "internal": {
      "enabled": true,
      "entries": {
        "session-memory": {
          "enabled": true
        }
      }
    }
  },
  "channels": {
    "discord": {
      "enabled": true,
      "token": "REDACTED",
      "groupPolicy": "allowlist",
      "guilds": {
        "1471887317315752151": {
          "channels": {
            "1471916061560406220": {}
          }
        }
      }
    }
  },
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "loopback",
    "auth": {
      "mode": "token",
      "token": "REDACTED"
    },
    "tailscale": {
      "mode": "serve",
      "resetOnExit": false
    },
    "nodes": {
      "denyCommands": [
        "camera.snap",
        "camera.clip",
        "screen.record",
        "calendar.add",
        "contacts.add",
        "reminders.add"
      ]
    }
  },
  "plugins": {
    "entries": {
      "discord": {
        "enabled": true
      }
    }
  }
}
```

## 4 agents to create

| Agent ID | Name    | Channel            | Discord Channel ID  | Model             |
| -------- | ------- | ------------------ | ------------------- | ----------------- |
| admin    | Clark   | #oc-admin          | 1471887664491008143 | zai/glm-4.7       |
| family   | Candace | #family-assistant  | 1471916061560406220 | zai/glm-4.7-flash |
| devwork  | Cody    | #devwork-assistant | 1471916342687826041 | zai/glm-4.7       |
| gamedev  | Clay    | #gamedev-assistant | 1471916406097445066 | zai/glm-4.7       |

Guild ID: `1471887317315752151`

All channels should have `requireMention: false` so every message in the channel is handled without needing to @Claw.

## Good place to start

Grep the openclaw dist to find valid binding match keys:

```bash
grep -o '"account"\|"peer"\|"group"\|"space"\|"channelId"\|"channel"' \
  /home/prill/.local/share/pnpm/global/5/.pnpm/openclaw@2026.2.16*/node_modules/openclaw/dist/subsystem-oVAQxyhr.js \
  | sort | uniq -c
```

Also check the agents subcommand docs:

```bash
openclaw agents add --help
openclaw docs agents
```

---

## Resolved

**Status:** Resolved on 2026-02-17

Solution documented in [multi-agent-routing-for-discord.md](multi-agent-routing-for-discord.md).
