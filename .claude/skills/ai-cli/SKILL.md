---
name: ai-cli
description: Design rules of the `ai` command of ai-cli — `ai <tool> [--name <chat name> | -p <prompt>]` or `ai local <command>`, every name abbreviable to its shortest unique prefix. Use before adding or renaming a tool, target or local command of `ai`, or when changing how `ai` parses its arguments.
---

# ai-cli: the `ai` command

The shape is fixed: `ai <tool> [--workspace <folder>] [--name <chat name> | -p <prompt>]`, or `ai local <command>`.

| Position | What | Rule |
|---|---|---|
| 1 | tool: `claude`, `grok`, `deepseek` (for now), or `local` | the AI or the toolbox that runs it |
| `--name` | chat name (AI tools) | the chat to open or resume in this folder, one argument; free words are an error for `claude` / `grok`, never a name nor a prompt |
| 2+ | command + args (`local`) | passed through unchanged |
| `-p` | one-shot prompt | the only way to send a headless prompt to `claude` / `grok`; `deepseek` has no chats yet, so its words are the prompt |

## Abbreviations

- Every tool and every local command is reachable by its **shortest unique prefix**: today `c`, `g`, `d`, `l`; when two names share a start, the prefix grows until it is unique (`ab...` / `ac...` take `ab` / `ac`).
- An exact name always wins over a longer one with the same start.
- Ambiguous or unknown prefixes print the candidates and exit 1; never guess.
- Flags follow the same rule: long names only, any unique prefix (`--w` = `--workspace`, `--n` = `--name`). No new one-letter flags; `-p` and `-h` stay only because claude, grok and every CLI use them.
- Adding a tool or command: check that it does not steal the one-letter prefix of an existing tool (`c`, `g`, `d`, `l`); if it would, rename it.

## Chats

- `claude`: `gitchat --name` (resume by session title in this folder, else new titled session; started in `~`, a name not found in `~` is resumed or created in `AI_CHAT_HOME`, default the folder holding ai-cli).
- `--workspace <folder>` (any unique prefix, value too): run claude or grok in that workspace, the folder holding ai-cli or one next to it; it replaces both the current folder and the `~` → `AI_CHAT_HOME` rule.
- `grok`: `grok -r <title>` (resume only: grok's CLI cannot title a new chat).
- A new AI tool joins with: a chat path (name → open/resume), a `-p` path, and a usage line. If it cannot keep named chats, say so in the usage and fall back to prompt only, like `deepseek`.

The user-facing reference is the `ai` section of the repo README; keep both in sync.
