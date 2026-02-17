# Multi-Agent Discord Routing for OpenClaw

**OpenClaw version:** v2026.2.16
**Resolved:** 2026-02-17

Route different Discord guild channels to separate OpenClaw agents, each with their own workspace, SOUL, model, and session history.

## Architecture

```
Discord Guild (1471887317315752151)
  #oc-admin          --> admin agent (Clark)      --> zai/glm-4.7
  #family-assistant   --> family agent (Candace)   --> zai/glm-4.7-flash
  #devwork-assistant  --> devwork agent (Cody)     --> zai/glm-4.7
  #gamedev-assistant  --> gamedev agent (Clay)     --> zai/glm-4.7
```

## Key Config Sections

### 1. Define agents in `agents.list` (array, not object)

Agents are defined in `agents.list` as an array of objects with `id` fields. The first agent in the list becomes the default.

```json
{
  "agents": {
    "defaults": {
      "model": { "primary": "zai/glm-4.7" },
      "workspace": "/home/prill/.openclaw/workspace"
    },
    "list": [
      {
        "id": "admin",
        "workspace": "~/.openclaw/workspace-admin",
        "model": { "primary": "zai/glm-4.7" }
      },
      {
        "id": "family",
        "model": { "primary": "zai/glm-4.7-flash" }
      },
      {
        "id": "devwork",
        "model": { "primary": "zai/glm-4.7" }
      },
      {
        "id": "gamedev",
        "model": { "primary": "zai/glm-4.7" }
      }
    ]
  }
}
```

**Gotchas:**

- Do NOT use `agents.entries` (keyed object) — the schema rejects it
- Agent names (Clark, Candace, etc.) go in SOUL.md files, not in the config
- If the first agent needs a custom workspace, set it explicitly (the default agent uses `agents.defaults.workspace`)

### 2. Bindings are top-level (not under `agents`)

```json
{
  "bindings": [
    {
      "agentId": "admin",
      "match": {
        "channel": "discord",
        "peer": { "kind": "channel", "id": "1471887664491008143" }
      }
    },
    {
      "agentId": "family",
      "match": {
        "channel": "discord",
        "peer": { "kind": "channel", "id": "1471916061560406220" }
      }
    }
  ]
}
```

**Gotchas:**

- Do NOT nest bindings under `agents.bindings` — the schema rejects it
- `match.channel` is **required** (string, e.g. `"discord"`)
- `match.peer` is an **object** `{ kind, id }`, not a string

### 3. Peer kind values (critical)

Discord uses three peer kinds:

| Kind        | Used for                                       |
| ----------- | ---------------------------------------------- |
| `"channel"` | Guild/server channels (text channels, threads) |
| `"group"`   | Group DMs only                                 |
| `"direct"`  | 1:1 DMs                                        |

**This is the #1 pitfall.** The web docs and AI-generated examples consistently show `"group"` for Discord channels, but the actual source code (`src/channels/chat-type.ts`) uses `"channel"` for guild channels. Using `"group"` causes bindings to silently fail — everything falls through to the default "main" agent with no error.

### 4. Guild channel allowlist with `requireMention: false`

With `groupPolicy: "allowlist"`, every channel must be listed. Add `requireMention: false` per-channel so the bot responds to all messages without needing @Claw.

```json
{
  "channels": {
    "discord": {
      "enabled": true,
      "token": "YOUR_BOT_TOKEN",
      "groupPolicy": "allowlist",
      "guilds": {
        "1471887317315752151": {
          "channels": {
            "1471887664491008143": { "requireMention": false },
            "1471916061560406220": { "requireMention": false },
            "1471916342687826041": { "requireMention": false },
            "1471916406097445066": { "requireMention": false }
          }
        }
      }
    }
  }
}
```

## SOUL.md Placement

Each agent's personality is defined by a `SOUL.md` file in its workspace directory:

```
~/.openclaw/workspace-admin/SOUL.md    --> Clark
~/.openclaw/workspace-family/SOUL.md   --> Candace
~/.openclaw/workspace-devwork/SOUL.md  --> Cody
~/.openclaw/workspace-gamedev/SOUL.md  --> Clay
```

Verify workspace paths with `openclaw agents list --verbose`.

**Important:** SOUL.md is only read when a new session is created. After placing or updating SOUL files, reset the agent's session:

```bash
openclaw sessions reset --agent <agentId>
```

If that doesn't work (sessions may all live under `agents/main/sessions/`), delete the session store directly:

```bash
rm ~/.openclaw/agents/main/sessions/sessions.json
```

## Binding Match Precedence

Bindings are evaluated in order. First match wins. The full precedence hierarchy:

1. `peer` — exact channel/DM/group match (highest)
2. `parentPeer` — thread inherits from parent channel
3. `guildId` + `roles` — Discord role-based routing
4. `guildId` — guild-wide routing
5. `teamId` — Slack team routing
6. `accountId` — account-level routing
7. `channel` — channel-wide fallback
8. Default agent — final fallback

## Debugging

### Verify config loads cleanly

```bash
journalctl --user -u openclaw-gateway.service -n 50 --no-pager
```

Look for "Unknown config keys" or "Config invalid" errors.

### Check agent routing

```bash
openclaw agents list --verbose
openclaw agents list --bindings
```

### Check session keys

```bash
openclaw sessions list
```

Sessions should show `agent:<agentId>:discord:channel:<channelId>`. If they all show `agent:main:*`, the bindings aren't matching.

### Check Discord channel resolution

```bash
openclaw channels health --verbose
```

Look for "channels unresolved" — means the bot can't see those channels (permissions issue on Discord side).

## Common Mistakes

| Mistake                                           | Symptom                                                   | Fix                                             |
| ------------------------------------------------- | --------------------------------------------------------- | ----------------------------------------------- |
| `agents.entries` instead of `agents.list`         | "Unrecognized keys" error on startup                      | Use `agents.list` (array with `id` fields)      |
| `agents.bindings` instead of top-level `bindings` | "Unrecognized keys" error on startup                      | Move `bindings` to top level                    |
| `peer.kind: "group"` for guild channels           | Bindings silently ignored, all traffic goes to main agent | Use `peer.kind: "channel"`                      |
| `peer` as string instead of object                | "expected object, received string" validation error       | Use `{ "kind": "channel", "id": "..." }`        |
| Missing `match.channel`                           | "expected string, received undefined" validation error    | Add `"channel": "discord"` to every match       |
| SOUL.md not loading                               | Agent uses generic personality                            | Reset session after placing SOUL.md             |
| Default agent workspace mismatch                  | First agent reads wrong SOUL.md                           | Set explicit `workspace` on first agent in list |
