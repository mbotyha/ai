# ai-cli toolbox

Terminal commands for AI/media workflows: drives a local Chromium-family browser or a remote browserless.io instance (via puppeteer-core, for ChatGPT) or `gallery-dl` (for Instagram/TikTok/X) using already-authenticated sessions instead of reinventing login/scraping, plus a set of `ffmpeg`/ImageMagick-based image and video utilities.

## Commands

Commands are grouped by area, one folder per area under `bin/`. `ai-cli --help` prints the same list.

### `ai-cli`
Lists all commands in this toolbox with a short description.

```
ai-cli --help
ai-cli doctor    # which browser chatgpt-image would use here (local family / browserless / none)
```


## ai

AI-driven image and video work: ChatGPT automation, face restoration, face redaction, video background removal.

### `ai`
One entry point for the toolbox: `ai <tool> --name <chat name>` opens (or resumes) a named chat with that AI, `-p` asks a one-shot question, `local` runs one of the CPU tools of this repo. v0 of the AI router: the tool is picked by hand; routing decisions move to Laya later.

```
ai c --name test-name                 # claude chat "test-name" of this folder: resumed if it exists, else new
ai c                                  # new unnamed claude chat
ai c --w <workspace> --n test-name    # claude chat "test-name" of another workspace, from any folder
ai g --name test-name                 # resume the grok chat titled "test-name" in this folder
ai c -p "summarize this repo"         # Claude Code, headless (claude -p)
ai g -p "summarize this repo"         # Grok, headless (grok -p)
ai d "explain MoE in 3 lines"         # DeepSeek via NVIDIA's free API (prompt only)
ai ats < input.json                   # ATS report of a CV against a job description, JSON out
ai local upscale photo.jpg            # any command of this toolbox
ai l u photo.jpg                      # same, abbreviated
ai l                                  # list the local commands
ai resume                             # reopen the chats a shutdown killed, see `ai-resume`
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `<tool>` | yes | `claude` / `grok` / `deepseek` / `ats` / `local` / `resume` | who runs it; `resume` passes its flags to [`ai-resume`](#ai-resume) |
| `--name <chat name>` | no | string | `claude` / `grok`: the chat to open or resume, one argument (quote a name with spaces); none = new unnamed chat; shortest form `--n`; not with `--prompt` |
| `--workspace <folder>` | no | a workspace, any unique prefix | `claude` / `grok`: run in that workspace (the folder holding this repo or one next to it) instead of the current folder; shortest form `--w` |
| `-p` / `--prompt <prompt...>` | no | string | `claude` / `grok`: headless one-shot answer instead of a chat; `deepseek` always works this way, `-p` optional |
| `<command> [args...]` | `local` only | a command below + its own args | passed through unchanged, so `ai l <command> --help` works |
| `--help` / `-h` | no | — | print usage and exit; also `ai <tool> --help`, and `ai l --help` lists the local commands |

- **Abbreviations**: every tool and local command accepts its shortest unique prefix: one letter when it is enough (`c`, `g`, `d`, `l`, `u`), more when names share a start (`ai l sl` = `slideshow`, `ai l gitp` = `gitpush`; two names `ab...` and `ac...` take `ab` and `ac`). An exact name always wins (`instagram-download` vs `instagram-download-batch`). Ambiguous or unknown names print the candidates. New tools and commands must keep `c`, `g`, `d`, `l` unique.
- **Flags**: long names only, each accepting its shortest unique prefix like the tools (`--w` = `--workspace`, `--n` = `--name`, `--p` = `--prompt`); `-p` / `--prompt` comes last, every word after it is the prompt. Free words outside `--prompt` are an error for `claude` / `grok` (the name goes in `--name`). No new one-letter flags: `-p` and `-h` exist only because `claude`, `grok` and every CLI use them. A new flag must keep `--w`, `--n` and `--p` unique.
- `ai c --name <name>` runs `gitchat --name <name>`: chats are per folder, matched by the claude session title.
- Started in `~` (terminals opened from the desktop UI), `ai c` and `ai c --name <name>` open a new chat in the project folder instead (`AI_CHAT_HOME`, default: the folder holding this repo), where the project's `.claude/settings.json` loads with the agent's narrow `gh pr merge` rule (auto mode does not apply broad user allows such as `Bash(*)`, while a narrow allow like that one is applied before its classifier). `ai c --name <name>` resumes a chat that already exists in `~`, in `~`; otherwise they resume or create it in `AI_CHAT_HOME`. Unnamed `ai c` from `~` always starts in `AI_CHAT_HOME`. Headless `ai c -p` keeps the current folder. `--workspace` overrides all of this: the chat is the one of that workspace (chats are per folder), resumed or created there.
- A session started in `~`, or in a folder whose `.claude/settings.json` (or the one of its git root) lacks the merge rule, prints a warning at start (`workspace-check` hook, registered by `install.sh`): the workspace's agent permissions are not loaded there. The warning, with the commands to fix it, shows on screen only; the agent is told just that gated actions need the owner's OK.
- `ai g --name <name>` runs `grok -r <name>` (title match in this folder, case-insensitive). Grok's CLI cannot title a new chat, so an unknown name fails: open it with `ai g` and give it the title inside grok.
- `ai local` reads the command list from `package.json` `bin`, so new commands show up without touching `ai`. The standalone names (`upscale`, `gitpush`, ...) keep working.
- `claude` and `grok` run the installed CLIs, using their own login. Output, exit code and signal are theirs; with `-p` piped stdin reaches them (`git diff | ai c -p "review this"`).
- `deepseek` calls `https://integrate.api.nvidia.com/v1` (OpenAI-compatible) through the Vercel AI SDK and streams the answer. Needs `NVIDIA_API_KEY` from the shell, else from this repo's `.env` (only the `NVIDIA_API_KEY`, `AI_DEEPSEEK_MODEL` and `AI_TIMEOUT_MS` keys are read from it, so other keys in that file never reach the spawned agents). Model from `AI_DEEPSEEK_MODEL`, default `deepseek-ai/deepseek-v4.1-flash`. Free tier, for trials only: ~40 requests/min, can queue for minutes when busy, so a call with no answer gives up after `AI_TIMEOUT_MS` (default 5 min). If the model leaves the answer empty and puts it all in its reasoning, the reasoning is printed. Needs Node >= 22.12 (the AI SDK is ESM-only).
- `ats` reads `{"cvMarkdown": "...", "jobDescription": "...", "language": "es-419"}` from stdin (`language` = BCP 47 tag of the report's free text, default `en-US`) and prints `{"score", "matchStatus", "missingHardSkills", "missingSoftSkills", "keywordDensityIssues", "formattingSuggestionsForPdf"}`. `matchStatus` (`excellent` >= 80, `good` >= 50, else `poor`) comes from the score, not from the model. Errors go to stderr with exit code 1. Model from `AI_ATS_MODEL` (default `anthropic/claude-sonnet-5.5`), routed by `bin/ai/router.js`: `deepseek-direct/<model>` and `nvidia/<model>` go straight to those APIs (`DEEPSEEK_API_KEY`, `NVIDIA_API_KEY`), every other id through the Vercel AI Gateway (`AI_GATEWAY_API_KEY`). Keys from the shell, else from this repo's `.env` (only those keys). The CV and the job description are sent to that provider. Needs a model with JSON-schema structured outputs (the Gateway ones): the direct prefixes only get JSON mode, so their answer may fail the schema.

### `ai-bridge`
HTTP door to the `ai` commands with a JSON stdin/stdout contract (today only `ats`), for callers that can only speak HTTP: os on Cloudflare Pages through a Cloudflare Tunnel, or a container next to it on the VPS Docker network. Same code in both cases, only the URL the caller uses changes.

```
AI_CLI_TOKEN=... ai-bridge
curl -X POST localhost:4011/ats -H "Authorization: Bearer $AI_CLI_TOKEN" -d @input.json
```

- `POST /<command>`: the body is piped to `ai <command>`; `200` + its JSON stdout, `502` + `{"error"}` with its stderr when it fails, `401` without the right `Authorization: Bearer $AI_CLI_TOKEN` (checked first), `404` for any other method or command, `413` above 1 MB.
- Refuses to start without `AI_CLI_TOKEN`. Listens on `AI_BRIDGE_HOST:AI_BRIDGE_PORT`, default `127.0.0.1:4011`; set `AI_BRIDGE_HOST=0.0.0.0` inside a container. All three from the shell, else this repo's `.env`; the command keys (`AI_GATEWAY_API_KEY`, ...) are read by `ai` itself.
- One child process per request, no queue; it is killed when the caller disconnects. The child does not get `AI_CLI_TOKEN`.

### `chatgpt-image`
Uploads an image to ChatGPT with a prompt and downloads the resulting generated image.

```
chatgpt-image --image ./photo.jpg --prompt "make the background blue"
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `--image` | yes* | file path | image to upload (relative or absolute) |
| `--prompt` | yes* | string | prompt text sent to ChatGPT |
| `--dump-cookies` | no | — | local login only: save `chatgpt-cookies.json` for use on a headless host, then exit |
| `--help` / `-h` | no | — | print usage and exit |

*not required with `--dump-cookies`.

- **Browser**: auto-detected — the OS default browser if it's Chromium-family, else `chrome`, `chromium`, `brave` in that order. Override with `AICLI_BROWSER=chrome|chromium|brave|/abs/path`. On a headless host (no `DISPLAY`) with `BROWSERLESS_API_KEY` set, it connects to browserless.io instead. `AICLI_BROWSER=browserless` forces that anywhere. Run `ai-cli doctor` to see the current pick. Full setup (browserless key, cookie workflow) in step 4 below.
- **Auth (local browser)**: a dedicated persistent profile at `bin/ai/chrome-profile-chatgpt/`. Tries headless first; if not logged in it opens a **visible** window and waits up to 5 minutes for a hand login, then continues.
- **Auth (browserless / headless)**: no persistent profile is possible over a remote connection, so it loads `bin/ai/chatgpt-cookies.json` (generate it on a desktop with `chatgpt-image --dump-cookies`, copy it over, or point `CHATGPT_COOKIES_FILE` elsewhere). Stale/missing cookies fail with an explicit message.
- Output: saved next to the input file as `<input-name>-mod.<ext>` (e.g. `photo-mod.png`).

### `create-virtual-ambassador`
Uploads every image in a folder to ChatGPT in one message with a fixed prompt asking for three full-body avatar variants derived from them, and saves each — built to turn a hand-picked shortlist of reference photos into a set of usable avatar candidates.

```
create-virtual-ambassador                    # uploads everything in ./references
create-virtual-ambassador ./some-photos
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `[images-dir]` | no | folder of images | positional argument, first non-flag arg — defaults to `./references` |
| `--dump-cookies` | no | — | local login only: save `chatgpt-cookies.json` for use on a headless host, then exit |
| `--help` / `-h` | no | — | print usage and exit |

- Shares its ChatGPT login/session (`bin/ai/chrome-profile-chatgpt/`, `bin/ai/chatgpt-cookies.json`) with `chatgpt-image` — see that section above for the browser/auth details, identical here.
- Prompt sent (fixed, not configurable): asks for three separate full-body, 1:1, transparent-background images derived from the references — (1) near-identical to the original, (2) resembling but not the same person, (3) only loosely inspired (broad traits kept, different face/identity). One line, no literal newlines — `page.type()` presses a real Enter for `\n`, which would submit the message mid-prompt.
- Output: `avatar/genesis-identical.<ext>`, `avatar/genesis-resembling.<ext>`, `avatar/genesis-inspired.<ext>` under the **current directory** (not `[images-dir]`) — extension follows whatever ChatGPT returns (typically `.png`). If ChatGPT returns a different number of images than three, they're saved as `avatar/genesis-1.<ext>`, `genesis-2.<ext>`, ... instead, since the identical/resembling/inspired labels only apply when the count matches the prompt's 3-item list.
- **Scoring**: each saved variant is then compared against a reference photo via the free tool at `quantilence.com/products/face-similarity` (browser-automated, no API key), and the match percentage is appended to its filename (e.g. `genesis-identical-94.png`). The reference photo is the first `profile.*` found checking, in order, `<cwd>/web/`, `<cwd>/instagram/`, `<cwd>/tiktok/`, `<cwd>/x/` (the layout `*-download-batch` produces). No reference found → scoring is skipped, filenames stay unscored. That site's comparison endpoint is rate-limited; a 429 gets one retry after a 20s wait, then scoring is skipped for that image only (the generated avatar is kept either way — a failed score never discards the image).
- If ChatGPT refuses on content-guideline grounds (nudity/sexuality/erotic content), this has no way to tell which of the uploaded images triggered it — it prints the refusal and the list of uploaded files so you can remove the suspect one by hand and try again. No automatic retry.

### `enhance-face`

Restores facial detail on a low-res or compressed portrait with GFPGAN v1.4 (CPU only), optionally upscaling the background with Real-ESRGAN. Unlike `upscale`, it rebuilds detail instead of just adding pixels.

```
enhance-face ./portrait.jpg              # 2x -> portrait@2x-face.jpg
enhance-face --scale 4 ./portrait.jpg
enhance-face --bg ./portrait.jpg         # also upscale the background (much slower)
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `<input>` | yes | image file (jpg/png/webp) | positional argument |
| `--scale` | no | integer > 1 | output size factor (default: `2`) |
| `--bg` | no | — | also upscale the background with Real-ESRGAN x2 (needs `WITH_BG=1` at setup) |
| `--help` / `-h` | no | — | print usage and exit |

- Needs a one-time setup of ~2 GB (CPU torch, GFPGAN, weights): `./install.sh --with-face`, or `bin/ai/enhance-face-setup.sh` directly. Add `WITH_BG=1` before it to also fetch the Real-ESRGAN weights for `--bg`.
- The venv and the weights live outside the repo, in `$ENHANCE_FACE_HOME` (default `~/.local/share/peaha-face`). Only the scripts are versioned.
- Output: `<name>@<N>x-face.<ext>` next to the input; the original is never touched.

### `redact-faces`
Blurs/redacts faces in an image or video via the Sightengine API (image vs video auto-detected from the file extension).

```
redact-faces --api-user U --api-secret S ./photo.jpg
redact-faces ./input.mp4   # if SIGHTENGINE_USER / SIGHTENGINE_SECRET are set
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `<input>` | yes | image or video file path | positional argument, first non-flag arg |
| `--api-user` | no* | string | Sightengine API user |
| `--api-secret` | no* | string | Sightengine API secret |
| `--help` / `-h` | no | — | print usage and exit |

*`--api-user`/`--api-secret` are required one way or another — either as flags, or via the `SIGHTENGINE_USER`/`SIGHTENGINE_SECRET` env vars (flags take precedence).

- Images: single synchronous call to Sightengine's Image Redaction API (`transform.json`).
- Videos: submits to the Video Redaction API (`video/transform.json`), then polls `video/byid.json` every 2s for up to 30 attempts (~1 minute) until the transform finishes, then downloads the result.
- Output: saved next to the input file as `<input-name>-redacted.<ext>`.

### `remove-bg-video`

Cuts the people out of a video and makes everything else transparent, with RobustVideoMatting (CPU only). The audio is kept (re-encoded to Opus). It is a person matting model: the background drops, but objects touching the person can stay (see the chair below).

```
remove-bg-video ./clip.mp4               # -> clip-nobg.webm
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `<input>` | yes | video file (anything ffmpeg reads) | positional argument |
| `--help` / `-h` | no | — | print usage and exit |

- Needs a one-time setup of ~1 GB (CPU torch, RVM weights): `./install.sh --with-bg-video`, or `bin/ai/remove-bg-video-setup.sh` directly.
- The venv and the weights live outside the repo, in `$REMOVE_BG_VIDEO_HOME` (default `~/.local/share/peaha-rvm`). Only the scripts are versioned.
- Output: `<name>-nobg.webm` next to the input (VP9 with alpha, Opus audio), written only when the whole video is done; the original is never touched.
- Speed, measured 2026-10-10 on a 14.6 s 720x1280 clip with 6 cores (the AI VPS size): 5 fps, ~70 s, ~1 GB RAM. With ffmpeg 4.4 (Ubuntu 22.04) the VP9 encoder is the bottleneck and the same clip takes ~146 s; ffmpeg 7.1 (Debian 13) runs at full speed.
- Uses every core it is given: run one video at a time.
- Known limits from the test: a chair back behind the shoulders stays in the cut-out, and subtitles burned into the video become half transparent (cut the clean video, add subtitles after).
- RobustVideoMatting is GPL-3.0: fine as a tool we run, not to be bundled into software we distribute.

## social

Downloaders for Instagram, TikTok and X, via `gallery-dl` and your logged-in Chrome cookies.

### `instagram-download`
Downloads a single Instagram reel, post, or photo.

```
instagram-download https://www.instagram.com/reel/XXXX/
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `<url>` | yes | Instagram post/reel URL | positional argument, first non-flag arg |
| `--help` / `-h` | no | — | print usage and exit |

- Auth: shells out to `gallery-dl --cookies-from-browser chrome`, which reads cookies straight from your everyday, already-logged-in default Chrome profile. No separate login flow to manage.
- Output: saved in the current directory as `username-publishTimestamp_num.ext` (e.g. `someuser-20260101T120000_1.mp4`); `_num` only matters for multi-image carousel posts, it's always `1` for reels and single photos. Uses the content's publish date, not the download date.

### `instagram-download-batch`
Downloads every post and story highlight from an Instagram profile.

```
instagram-download-batch someusername
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `<username-or-url>` | yes | username or full profile URL | positional argument, first non-flag arg |
| `--help` / `-h` | no | — | print usage and exit |

- Auth: same as `instagram-download` (`--cookies-from-browser chrome`).
- Output: saves into an `instagram/` subfolder in the current directory (shared across all profiles, not one folder per profile), files named like `instagram-download` plus the gallery-dl subcategory after the user (`posts`, `highlights`, `avatar`, ...), which is how the avatar is recognised. Keeps an `instagram/.downloaded.sqlite3` archive so reruns skip posts already downloaded.
- After each run, images are moved into `instagram/img/` and reels/videos into `instagram/vid/` (flattening any per-highlight subfolder gallery-dl created), regardless of exit status — so a partial download still gets sorted.
- Also downloads the profile's current avatar to `instagram/profile.<ext>` — used as a reference photo (e.g. for `create-virtual-ambassador`'s face-similarity scoring).

### `tiktok-download`
Downloads a single TikTok video or photo post.

```
tiktok-download https://www.tiktok.com/@someuser/video/XXXX
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `<url>` | yes | TikTok video/photo URL | positional argument, first non-flag arg |
| `--help` / `-h` | no | — | print usage and exit |

- Auth: shells out to `gallery-dl --cookies-from-browser chrome`, same as the Instagram commands. TikTok's public posts often work without cookies, but logged-in cookies help with region-locked or otherwise gated content.
- Output: saved in the current directory as `user-publishTimestamp_num.ext` (e.g. `someuser-20260101T120000_1.mp4`); `_num` only matters for multi-image posts.

### `tiktok-download-batch`
Downloads every post from a TikTok profile.

```
tiktok-download-batch someusername
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `<username-or-url>` | yes | username or full profile URL | positional argument, first non-flag arg |
| `--help` / `-h` | no | — | print usage and exit |

- Auth: same as `tiktok-download` (`--cookies-from-browser chrome`).
- Output: saves into a `tiktok/` subfolder in the current directory (shared across all profiles, not one folder per profile), files named like `tiktok-download` plus the gallery-dl subcategory after the user (`posts`, `highlights`, `avatar`, ...), which is how the avatar is recognised. Keeps a `tiktok/.downloaded.sqlite3` archive so reruns skip posts already downloaded.
- After each run, images are moved into `tiktok/img/` and videos into `tiktok/vid/`, regardless of exit status — so a partial download still gets sorted.
- Also downloads the profile's current avatar to `tiktok/profile.<ext>` — used as a reference photo (e.g. for `create-virtual-ambassador`'s face-similarity scoring).

### `x-download`
Downloads a single X (Twitter) post's media.

```
x-download https://x.com/someuser/status/XXXX
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `<url>` | yes | X/Twitter post URL | positional argument, first non-flag arg |
| `--help` / `-h` | no | — | print usage and exit |

- Auth: shells out to `gallery-dl --cookies-from-browser chrome`, same as the other platform commands.
- Output: saved in the current directory as `handle-publishTimestamp_num.ext`; `_num` only matters for multi-image posts.

### `x-download-batch`
Downloads every media post from an X (Twitter) profile — text-only posts and replies without a photo/video are skipped entirely (gallery-dl's own "media" tab filter, not a client-side one).

```
x-download-batch someusername
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `<username-or-url>` | yes | username or full profile URL | positional argument, first non-flag arg |
| `--help` / `-h` | no | — | print usage and exit |

- Auth: same as `x-download` (`--cookies-from-browser chrome`).
- Output: saves into an `x/` subfolder in the current directory (shared across all profiles, not one folder per profile), files named like `x-download` plus the gallery-dl subcategory after the user (`posts`, `highlights`, `avatar`, ...), which is how the avatar is recognised. Keeps an `x/.downloaded.sqlite3` archive so reruns skip posts already downloaded.
- After each run, images are moved into `x/img/` and videos into `x/vid/`, regardless of exit status — so a partial download still gets sorted.
- Also downloads the profile's current avatar to `x/profile.<ext>` — used as a reference photo (e.g. for `create-virtual-ambassador`'s face-similarity scoring).

## media

Image and video utilities on `ffmpeg`, ImageMagick and `sharp`.

Video editing beyond these commands (captions, silence cuts, loudness, platform exports, sync) goes through the vendored [`ffmpeg-skill`](https://github.com/kajisho5/ffmpeg-skill) (MIT, pinned at 2.17.3) in `.claude/skills/ffmpeg-skill/`, loaded in Claude Code sessions started in this repo. Needs FFmpeg >= 5.0 (6.1+ recommended) and Python 3.9+; `python3 .claude/skills/ffmpeg-skill/scripts/_contract.py doctor` checks the machine.

- Its scripts do not pass `-protocol_whitelist` to ffmpeg, so a crafted file (a playlist named `.mp4`) can make ffmpeg open network URLs. Use it on our own footage; a downloaded file (`social/` commands, anything from outside) is remuxed to a plain local file first: `ffmpeg -protocol_whitelist file -i in.mp4 -c copy -map 0 clean.mp4`.
- Update: `npx ffmpeg-skill@<version> --project` from this repo root, after reading that version's `bin/install.js`; never the bare `npx ffmpeg-skill`, which installs into the user profile.

### `image-to-jpg`
One command for any supported source format, dispatched by file extension — same behaviour as `webp-to-jpg` / `heic-to-jpg`, just picked automatically. Currently supports `.webp`, `.heic`, `.heif`, `.avif`; a folder input can mix formats freely.

```
image-to-jpg ./photo.webp               # -> photo.jpg, photo.webp deleted
image-to-jpg ./IMG_0001.heic            # -> IMG_0001.jpg, IMG_0001.heic deleted
image-to-jpg --keep ./photo.heic        # -> photo.jpg, photo.heic preserved
image-to-jpg ./camera-roll              # every supported file in the folder -> .jpg
image-to-jpg                            # every supported file in the current folder -> .jpg
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `[input]` | no | supported image file **or** folder of them | positional argument, first non-flag arg — defaults to `.` (current folder) |
| `--quality` | no | 1-100 | JPEG output quality — ImageMagick-based formats only (`.heic`/`.heif`/`.avif`); ignored for `.webp` (default: `92`) |
| `--keep` | no | — | keep the original file(s) instead of deleting them |
| `--help` / `-h` | no | — | print usage and exit |

- Extensions are looked up in a `CONVERTERS` map at the top of `bin/media/image-to-jpg.js` — adding a new source format later means adding one entry there, nothing else changes.
- Output: `<name>.jpg` next to the input, in the same folder. By default the original is deleted after a successful conversion — pass `--keep` to preserve it. An existing `<name>.jpg` is never overwritten: that input is skipped and left in place, and the command exits 1.

### `heic-to-jpg`
Converts an iPhone `.heic`/`.heif` image, or every one in a folder, to `.jpg`.

```
heic-to-jpg ./IMG_0001.heic             # -> IMG_0001.jpg
heic-to-jpg --quality 85 ./photo.heic   # -> photo.jpg, quality 85
heic-to-jpg ./camera-roll               # every .heic/.heif in the folder -> .jpg
heic-to-jpg                             # every .heic/.heif in the current folder -> .jpg
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `[input]` | no | `.heic`/`.heif` file **or** folder of them | positional argument, first non-flag arg — defaults to `.` (current folder) |
| `--quality` | no | 1-100 | JPEG output quality (default: `92`) |
| `--keep` | no | — | keep the original `.heic`/`.heif` file(s) instead of deleting them |
| `--help` / `-h` | no | — | print usage and exit |

- Wraps `convert <in> -auto-orient -quality N <out.jpg>` — `-auto-orient` bakes in the EXIF rotation iPhone HEIC files carry, so the JPEG isn't sideways.
- Output: `<name>.jpg` next to the input, in the same folder. By default the original is deleted after a successful conversion — pass `--keep` to preserve it. An existing `<name>.jpg` is never overwritten: that input is skipped and left in place, and the command exits 1.

### `webp-to-jpg`
Converts a `.webp` image, or every one in a folder, to `.jpg`.

```
webp-to-jpg ./photo.webp                # -> photo.jpg, photo.webp deleted
webp-to-jpg --keep ./photo.webp         # -> photo.jpg, photo.webp preserved
webp-to-jpg ./icons                     # every .webp in the folder -> .jpg
webp-to-jpg                             # every .webp in the current folder -> .jpg
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `[input]` | no | `.webp` file **or** folder of them | positional argument, first non-flag arg — defaults to `.` (current folder) |
| `--keep` | no | — | keep the original `.webp` file(s) instead of deleting them |
| `--help` / `-h` | no | — | print usage and exit |

- Wraps `ffmpeg -i <in> <out.jpg>`.
- Output: `<name>.jpg` next to the input, in the same folder. By default the original is deleted after a successful conversion — pass `--keep` to preserve it. An existing `<name>.jpg` is never overwritten: that input is skipped and left in place, and the command exits 1.
- Ported from a `webptojpg()` bash function that used to live in `~/.bashrc` (removed from there — this is now the canonical version).

### `upscale`
Resamples an image, or every image in a folder, up by an integer factor.

```
upscale ./frame.png                     # 2x, -> frame@2x.png
upscale --scale 3 ./frame.png           # 3x, -> frame@3x.png
upscale ./animation-frames              # 2x every image -> animation-frames@2x/
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `<input>` | yes | image file **or** folder of images | positional argument, first non-flag arg |
| `--scale` | no | integer > 1 | resize factor per side (default: `2`) |
| `--help` / `-h` | no | — | print usage and exit |

- Wraps `convert <in> -colorspace RGB -filter Lanczos -resize <N*100>% -colorspace sRGB -unsharp 0x0.75+0.6+0.008 -strip <out>` — resize is done in linear light, with a light sharpen pass to counter the softening.
- This is a plain resample: more pixels, **no invented detail**. For a genuine ML upscale (sharper skin/hair/edges) install `realesrgan-ncnn-vulkan` and run that instead.
- Recognised image extensions: `.jpg .jpeg .png .webp .bmp .tif .tiff`. A folder input skips everything else.
- Output: a file becomes `<name>@<N>x.<ext>` next to the input; a folder fans out to a sibling `<folder>@<N>x/` with the same file names. Originals are never touched.

### `watermark`
Tiles a text watermark over images and videos, detected from the file extension. Without an input it processes every image and video in the current folder.

```
watermark --text "example.com"                        # every image/video in the current folder
watermark --text "example.com" ./photo.jpg ./clip.mp4
watermark --text "example.com" --rotation -45 --color '#4FB3E8' ./folder --recursive
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `<input>` | no | files and/or folders | positional; none = current folder; a folder = its images/videos, not its subfolders |
| `--text` | yes | string | watermark text |
| `--opacity` | no | 0–1 | watermark opacity (default: `0.25`) |
| `--font-size` | no | 1–1000 | font size in px on images; on videos scaled with the frame (default: `36`) |
| `--rotation` | no | degrees | text rotation, negative = counter-clockwise (default: `0`) |
| `--color` | no | color | name, `'#hex'` (quote it, bash treats `#` as a comment) or `rgb()` (default: `black`) |
| `--recursive` | no | — | folders: include subfolders too |
| `--help` / `-h` | no | — | print usage and exit |

- Each copy of the text sits in a tile of at least 256×256px that grows with the text and the rotation. Text width is estimated (0.6em per char), not measured, so very wide glyphs can still clip. Tiles over 4096px are refused.
- Images: the tile is composited at native pixel size via `sharp`.
- Videos: the first frame (`ffmpeg`) gives the real pixel size, the tile is scaled so 256px = 1/3 of the frame's short side, and the resulting full-frame PNG is overlaid on every frame (`ffmpeg -filter_complex overlay`, audio copied untouched). Re-encoding is CPU-bound and can be slow on long or high-resolution videos.
- Output: `<input-name>-watermark.<ext>` next to each input, overwritten on re-run. Folder scans skip files already named `*-watermark.*`, so a re-run never stacks watermarks.

### `text-overlay`
Draws a single line of text over an image or a video (input type auto-detected from the file extension).

```
text-overlay --text "Ma se sbagli: 50% di tasse" ./photo.jpg
text-overlay --text "hello" --position bottom --start 0 --end 3 ./input.mp4
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `<input>` | yes | image or video file path | positional argument, first non-flag arg |
| `--text` | yes | string | text to draw (or set env `TEXT_OVERLAY_TEXT`) |
| `--position` | no | `top` \| `center` \| `bottom` | vertical placement, always horizontally centered (default: `top`) |
| `--fontsize` | no | number | font size in px (default: `48`) |
| `--color` | no | ffmpeg color name or `#hex` | font color (default: `white`) |
| `--start` | no | seconds | video only: when the text appears (default: `0`) |
| `--end` | no | seconds | video only: when the text disappears (default: end of clip) |
| `--help` / `-h` | no | — | print usage and exit |

- Text is always drawn with a 2px black border for legibility. `--start`/`--end` are ignored for images (the overlay is permanent).
- Passed to `drawtext` via a temp `textfile` with `expansion=none`, so `:` `%` `'` `,` in the text need no escaping and don't trigger drawtext's `%{...}` expansion.
- Images: `ffmpeg -i in -vf drawtext=... -q:v 2 out` (single frame, quality preserved). Videos: adds `enable='between(t,start,end)'`, re-encodes `libx264 -crf 18`, drops audio (`-an`).
- Output: saved next to the input file as `<input-name>-overlay.<ext>`.

### `aspect-ratio`
Crops an image or a video to an aspect ratio: the classic `16:9`, `9:16`, `4:3`, `3:4`, `1:1`, or any `x:y`. Keeps the largest centered area, no scaling, no black bars.

```
aspect-ratio --ratio 9:16 ./clip.vid.mp4    # -> clip.vid.9_16.mp4
aspect-ratio --ratio 1:1 ./photo.jpg        # -> photo.1_1.jpg
aspect-ratio --ratio 21:9 ./clip.mov        # -> clip.21_9.mov
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `<input>` | yes | image or video file | positional argument, first non-flag arg |
| `--ratio` | yes | `x:y` (integers 1-99999) | target aspect ratio |
| `--help` / `-h` | no | — | print usage and exit |

- Image or video is detected with `ffprobe` from the container, not the file name: a still image opens as the `image2` or a `*_pipe` demuxer (`png_pipe`, `jpeg_pipe`, `webp_pipe`, ...) or `jpeg_mpf` (multi-picture phone JPEG, first picture); a `.gif`/`.apng` is an image only with a single frame. A file with no video stream, or with only a cover picture (`.mp3`/`.m4a` artwork), is rejected, and so is a playlist (`hls`, `dash`, `concat`).
- Exact ratio: crops `(x*k) by (y*k)` centered, `k = m * floor(min(w/x, h/y) / m)`, via `ffmpeg -vf "crop='x*k':'y*k'"`. On video `m = 2` when `x` or `y` is odd, so both sides stay even for yuv420 encoders (`1920x1080` → `9:16` = `594x1056`); on images `m = 1` with `exact=1`, so odd sides survive on 4:2:0 JPEGs too (`1001x777` → `1:1` = `777x777`).
- Videos: re-encoded with ffmpeg's default encoder for the extension, audio copied (`-c:a copy`), rotation metadata applied before the crop. Images: single frame, `-q:v 2`; a `%` in the file name stays literal.
- Input is read with `-protocol_whitelist file`, so a downloaded playlist-like file can't make ffmpeg fetch URLs.
- Not handled: anamorphic video (non-square pixels, crop is in stored pixels) and HDR/10-bit sources (the default encode is 8-bit). `.heic`/`.avif`: convert first with `image-to-jpg --keep`.
- Output: `<input-name>.<x>_<y>.<ext>` next to the input, overwritten if it exists.
- `aspect-ratio --selftest` builds test videos and images in a temp folder and checks detection, crop sizes, `%` names, audio and output name.

### `get-first-frame`
Extracts the first frame of a video as a JPEG.

```
get-first-frame ./input.mp4
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `<input>` | yes | video file path | positional argument, first non-flag arg |
| `--help` / `-h` | no | — | print usage and exit |

- Wraps `ffmpeg -i input.mp4 -frames:v 1 output.jpg`.
- Output: saved next to the input file as `<input-name>-first-frame.jpg`.

### `get-last-frame`
Extracts the last frame of a video as a JPEG.

```
get-last-frame ./input.mp4
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `<input>` | yes | video file path | positional argument, first non-flag arg |
| `--help` / `-h` | no | — | print usage and exit |

- Wraps `ffmpeg -sseof -3 -i input.mp4 -update 1 -q:v 2 output.jpg` (seeks to 3s before end and keeps re-decoding until the last frame, since videos don't always have a keyframe exactly at EOF).
- Output: saved next to the input file as `<input-name>-last-frame.jpg`.

### `blur-video`
Blurs a video from a given second to the end, in two ramping phases (medium blur for 4s, then heavy blur for the rest).

```
blur-video --at 19 ./input.mp4
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `<input>` | yes | video file path | positional argument, first non-flag arg |
| `--at` | yes | seconds (number) | second the blur starts at |
| `--help` / `-h` | no | — | print usage and exit |

- Wraps `ffmpeg -vf "boxblur=25:1:enable='between(t,AT,AT+4)',boxblur=50:1:enable='gte(t,AT+4)'" -c:v libx264 -crf 18 -an`.
- The 4s ramp is currently hardcoded (matches the original 19→23 example); re-encodes video (`libx264`, `crf 18`), drops audio.
- Output: saved next to the input file as `<input-name>-blurred.<ext>`.

### `slideshow`
Turns the images and videos of a folder, or an explicit list of files, into one silent mp4: images held for `--duration` seconds, videos merged in full.

```
slideshow                               # every image/video in the current folder -> ./slideshow.mp4
slideshow ./photos                      # every image/video in ./photos -> ./photos/slideshow.mp4
slideshow c.jpg intro.mp4 a.jpg b.png   # exactly these, in this order -> ./slideshow.mp4
slideshow --fill ./photos               # fill the frame: photos cropped around the people found, videos center-cropped
slideshow --ratio 9:16 --fill ./photos     # vertical, for Reels/TikTok/Stories
slideshow --duration 2 --ratio 16:9 --output reel.mp4 ./photos
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `[input]` | no | nothing, **one** folder, **or** one or more image/video files | no input = current folder; a folder = all its images and videos (not its subfolders, unless `--recursive`), natural-sorted (`img2` before `img10`); files = that exact order |
| `--duration` | no | seconds (number) | how long each image stays on screen; videos always play in full (default: `3`) |
| `--ratio` | no | `W:H` | aspect ratio of the output, e.g. `1:1`, `16:9`, `9:16`, `4:3`, `3:4`; the short side is always 1080 px (`16:9` → 1920x1080, `4:3` → 1440x1080) (default: `1:1`) |
| `--fill` | no | — | fill the whole frame instead of letterboxing: images are cropped around the people and faces detected on CPU (see below), videos are center-cropped |
| `--recursive` | no | — | folder input: include subfolders too (default: top level only) |
| `--output` | no | file path | output mp4 (default: `<folder>/slideshow.mp4` for a folder, `./slideshow.mp4` for a file list) |
| `--help` / `-h` | no | — | print usage and exit |

- Accepted images: `.jpg`, `.jpeg`, `.png`, `.webp`, `.bmp`, `.tif`, `.tiff`; convert `.heic`/`.avif` first with `image-to-jpg --keep`. Accepted videos: `.mp4`, `.mov`, `.m4v`, `.webm`, `.mkv`.
- Default framing: each input is fitted inside the `--ratio` frame and letterboxed with black bars, never cropped or stretched.
- Images are pre-processed with `sharp`, one at a time: the EXIF orientation is always applied (ffmpeg 4.4 ignores it, so phone photos rotated only in metadata would come out sideways); images without an orientation tag go to ffmpeg untouched.
- `--fill` (`bin/lib/subject-crop.js`): each image is scanned on CPU with `onnxruntime-node` by two small detectors, [YOLOX-tiny](https://github.com/Megvii-BaseDetection/YOLOX) for people (Apache-2.0, 20 MB) and [YuNet](https://github.com/opencv/opencv_zoo/tree/main/models/face_detection_yunet) for faces (MIT, 0.2 MB, the `2026may` dynamic-size export, run like OpenCV does: at the photo's own aspect, padded to a multiple of 32, first with the long side at 960 px for small faces, then at 320 px if nothing was found, for close-ups); about 0.1-0.25 s per photo. The crop window has the largest size of the `--ratio` aspect that fits the photo, and is placed so that:
  - people whose box area is under 30% of the biggest person's (background crowds) are ignored; faces count only when their center is inside one of the remaining people, whatever their size (a child next to an adult stays, a blurred face in the background does not); with no person detected, faces under 25% of the biggest face's area are ignored;
  - the faces are inside it; when several faces cannot fit together, the biggest face and its person win; a single face bigger than the window cannot fit and is centered;
  - the whole subject (main people + faces) is centered when it fits;
  - when a body is taller than the window, the face sits near the top with the body below.

  Photos with nobody detected fall back to `sharp`'s `attention` heuristic (a line is printed for each). Videos get a plain center crop in ffmpeg. The models are downloaded once into `~/.cache/ai-cli/models` (or `$XDG_CACHE_HOME/ai-cli/models`) from pinned URLs (a YOLOX release, an `opencv_zoo` commit), capped at 64 MB and checked against pinned sha256 hashes: a mismatch is never used, and a missing or bad download stops the run with an error. No GPU, paid API or generative model is involved: the photo is only cropped, never redrawn.
- Encoding: one ffmpeg run per file, one at a time, so memory stays flat whatever the number of files (~550 MB peak on 2 cores; a single graph with every input open needed 4.7 GB for 24 photos). Each file becomes a segment: `scale`+`pad` (or `scale`+`crop` with `--fill`) to the frame, stills read at 1 fps and trimmed to the exact `--duration`, `libx264` (default High profile, preset `medium`), `crf 20`, 30 fps, `yuv420p`, converted to and tagged as BT.709 limited range (the stream copy keeps the first segment's color tags for the whole file, so every segment carries the same ones). The segments are then joined with the concat demuxer as a stream copy, `+faststart`. On 2 CPU cores a `--fill` slideshow encodes at about real time (60 s for 62 s of video). Plays in browsers, VLC and phone galleries; not tested against the upload limits of WhatsApp or Instagram.
- The output is always silent: the audio of input videos is dropped. Hard cuts, no transitions. An existing output file is never overwritten: the command exits 1. A failed or interrupted run (Ctrl+C) deletes its own partial output and temp files.
- `--selftest` checks the input planning, the ratio → frame size math, the generated ffmpeg segment/concat arguments, the subject crop geometry and both detector decoders on hand-made outputs (these need no models), then the `--fill` crop size and the EXIF rotation, without rendering a video (the first run downloads the models).

## dev

Git and editor helpers.

### `gitpush`

Runs a push an AI agent prepared for you. Each push is its own entry in the gitpool of the project, `<project>/.gitpool/<repo>/<id>/`: `message` (commit message, also the PR title and body) and `script` (`cd`, commit or re-sign, `git push`, PR). You review and run `gitpush`; the commits are signed with your key and pushed with your credentials, the agent never pushes on its own.

```
gitpush                 # the only pending entry, or a menu when there are several
gitpush <n>             # one entry by serial number (the <n>- prefix of its id), from any folder
gitpush <repo>/<id>     # one entry by name
```

- Entry ids are `<n>-<slug>`; agents take `<n>` from the shared counter `~/.peaha/gitpool.seq`.
- Pool lookup without argument: the `.gitpool` of the project you are in (searched upwards from the current folder, stopping before `$HOME`); with an argument, or from anywhere else, the `.gitpool` of every project next to the one holding ai-cli.
- Entries never overwrite each other, so parallel agents can each prepare a push.
- A successful script removes its own entry: what is left in `.gitpool` is what is still pending.
- Refuses a script that is a symlink, not owned by you, or merges a PR (the agent merges from its session, per the prepare-gitpush skill).

### `github-events`
Prints GitHub events as they happen, one JSON line each: pushes, PR opened/merged, reviews, review and issue comments, completed checks and workflow runs, commit statuses. Agents run it as a background monitor to wake up instead of polling GitHub; the line is a hint, the current state is still read with `gh`. Events come from the `github-events` Worker (below), which keeps them 30 days: without `--since` the output starts from now, `--since <seq>` replays what came after that event (for example while the laptop was off).

```
github-events                          # every repo, from now on
github-events --repo ara-peaha-ai/os
github-events --repo ara-peaha-ai/os --pr 52             # one PR (also check runs listing it)
github-events --repo ara-peaha-ai/os --ref refs/heads/main
github-events --since 120              # replay what came after event 120, then live
```

- Line shape: `{"seq", "ts", "event", "action", "repo", "actor", ...}` (`action` empty for push and status) plus per event `pr` (PR comment) or `issue` (issue comment), `prs` (check run), `sha`, `state`, `conclusion`, `name`, `ref`, `created` / `deleted` / `forced` (push; no `sha` on a delete), `assoc` (author association), `text` (first 200 chars, whitespace collapsed).
- `--repo` is case-insensitive; `--pr` and `--ref` are exact.
- `--once` exits 0 after the first matching push that is not a branch delete (a background wait that ends when the push lands; the caller still runs its own landed check); `--tip` prints the last stored event seq and exits (a `--since` starting point).
- Reconnects on its own every 5 s and resumes from the last event it got; a replay longer than 500 events continues on its own. Exits 1 when it never connects (missing config, wrong token, Worker down), with the reason on stderr.
- Reads `~/.peaha/github-events.env`, written by `github-events-setup`.

### `gitpool-landed`
Says which agent-prepared pushes have landed, even days after they were prepared. For each gitpool entry it prepares, the agent writes `~/.peaha/gitpool-watch/<entry id>.watch` (`repo=`, `branch=`, `subject=`, `started=` lines) and deletes it once it has handled the landed push.

```
gitpool-landed           # every record: landed, pending, unknown (fetch failed), invalid or missing repo
gitpool-landed --hook    # landed ones only, silent when none
```

- `install.sh` registers `gitpool-landed --hook` as a Claude Code `SessionStart` hook, so a new session starts knowing what landed while no session was watching. The hook lists only records of repos inside the session folder (or holding it), prints id, repo and branch only (never the commit subject), and caps its fetches at about 20 s.
- Landed = after a successful fetch, the commit subject is among the last 50 commits of `origin/<branch>` made after `started`, the same check the agent's watcher uses. A branch name `git check-ref-format --branch` rejects is never fetched.

### `github-events-setup`
Deploys the `github-events` Cloudflare Worker (`workers/github-events/`) and points GitHub webhooks at it. Safe to re-run: it keeps the secrets and updates the webhooks it created.

```
github-events-setup                      # your user + the orgs you admin (first run), then the saved ones
github-events-setup my-org another-org my-user
```

- Org: one org webhook. User account: one webhook per own repo, forks and archived ones skipped (GitHub has no user-level webhook), so re-run it after creating a repo.
- Needs `wrangler` logged in (`CLOUDFLARE_ACCOUNT_ID` when the login has several accounts) and `gh` with the `admin:org_hook` scope: `gh auth refresh -s admin:org_hook`.
- Worker: `POST /webhook` checks the `X-Hub-Signature-256` HMAC, drops redeliveries of the same `X-GitHub-Delivery`, keeps the event 30 days in a Durable Object (SQLite); `GET /ws` streams them over a WebSocket, auth by the `v1, <CLIENT_TOKEN>` subprotocols, `?repo=` and `?since=` as above. Without its secrets it refuses every request. Check: `npx wrangler@4.75.0 dev --port 8799 --var WEBHOOK_SECRET:testsecret --var CLIENT_TOKEN:testtoken` in `workers/github-events/`, then `node workers/github-events/check.mjs`.
- `./install.sh --with-github-events` runs it on a new machine; after that every `./install.sh` re-deploys it on its own. A failed deploy or webhook update prints an error and leaves the rest of the install in place.
- Secrets in `~/.peaha/github-events.env` (mode 600). Second machine of the same person: copy that file there first, else the setup makes new secrets and the first machine stops receiving.

### `gitchat`

Opens a named Claude Code session for the current folder: resumes it if a session with that name already exists here, otherwise creates it. Prints which one it did before opening.

```
gitchat --name email-verein
gitchat --ai claude --name email-verein
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `--name` / `-n` | yes | string | session name |
| `--ai` | no | `claude` | assistant; only `claude` for now (grok has no session names) |
| `--help` / `-h` | no | — | print usage and exit |

- Looks the name up in `~/.claude/projects/<slug of the current path>/*.jsonl`: only the `custom-title` record line written by `/rename`, never text quoted inside a transcript; the most recently modified matching session wins. Reads Claude Code's on-disk format, so a future change there can break the lookup.
- A new session opens with `/rename <name>` as its first message (visible in the chat), not `claude -n`, which often left the session unnamed.
- Names cannot contain `"` or `\`.
- Sessions are per folder: if the name exists only in another folder, it says so and creates a new one here.

### `ai-resume`

Same as `ai resume`. Reopens the Claude Code sessions that a shutdown or crash killed, one gnome-terminal tab each, in each session's own folder. Named sessions get their name back as the tab title (`claude --resume <id> -n <name>`); unnamed ones let Claude set the title from the chat topic.

```
ai resume                          # sessions killed by the last shutdown/crash
ai resume --sessions truncated     # sessions killed by any shutdown/crash the journal remembers
ai resume --dry-run                # list them, open nothing
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `--sessions` | no | `last` \| `truncated` | `last` = only the previous boot; `truncated` = every previous boot in the journal (default: `last`) |
| `--ai` | no | `claude` | which AI's sessions to reopen; only `claude` for now (default: `claude`) |
| `--dry-run` | no | — | print date, session id, name and folder of each match, open nothing |
| `--help` / `-h` | no | — | print usage and exit |

- A session counts as killed when its transcript (`~/.claude/projects/*/<id>.jsonl`) was last written between 120 s before and 5 s after a boot ended. A boot ends at its last journal record (`journalctl -b <n> -n 1`), so they cover crashes too, and the history is as long as journald keeps it.
- On a clean shutdown Claude Code writes every open session when it gets SIGTERM, so idle sessions are caught too. On a hard power loss nothing is written: only the sessions that were active in those last 120 s are found.
- A reopened session is written to again, so it stops matching: running `ai resume` twice does not open duplicates.
- A session closed by hand in the 120 s before the shutdown is reopened too.
- Desktop only: needs `claude`, `gnome-terminal`, `journalctl` and `jq`. Transcripts are read from `$CLAUDE_CONFIG_DIR/projects` when that is set.

### `repo-split-branches`

Checks out every branch of a GitHub repo into its own folder (a git worktree), so several branches can be open side by side without switching.

```
repo-split-branches --repo owner/name                    # every remote branch
repo-split-branches --repo owner/name --branch docs/xyz  # just one
repo-split-branches --repo owner/name --dir ~/work       # somewhere other than the current folder
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `--repo` | yes | `owner/name` | GitHub repo; cloned over SSH into `<dir>/<name>` if not there yet |
| `--branch` | no | branch name | split only this branch (must exist on `origin`) |
| `--dir` | no | folder | where `<name>` and the worktrees live (default: current folder) |

- `<dir>/<name>` stays on its current branch; every other branch gets `<dir>/<name>-<branch>` (`/` becomes `-`, e.g. `docs/xyz` -> `name-docs-xyz`).
- Existing folders and branches already checked out elsewhere are skipped, never overwritten.
- Worktrees share one `.git`: no history is duplicated, but each folder needs its own `npm install`.

### `repo-join-branches`

The reverse of `repo-split-branches`: folds every `<name>-*` worktree folder back into `<name>`.

```
repo-join-branches --repo owner/name
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `--repo` | yes | `owner/name` | same repo given to `repo-split-branches` |
| `--dir` | no | folder | same `--dir` given to `repo-split-branches` (default: current folder) |

- Uncommitted changes in a worktree are saved as a local `wip: uncommitted changes from <folder>` commit on that branch, then the folder is removed. The branch stays in `<name>`: `git switch <branch>` to get back to it.
- Never pushes. Branches with commits not on `origin` are listed at the end.
- Only touches `<name>-*` folders next to `<name>`; worktrees created elsewhere (e.g. by AI agents) are left alone.
- Gitignored files (`.env`, `node_modules`) are not committed and are deleted with the folder: copy any `.env` out first.

### `search-string`
Searches file names and file content for a string in a directory (recursive, `.git` and `node_modules` excluded).

```
search-string sometext
search-string sometext --case true --directory ~/foo/bar
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `<string>` | yes | string | positional argument, first non-flag arg |
| `--case` | no | `true` \| `false` | case-sensitive search (default: `false`) |
| `--directory` | no | directory path (`~` expanded) | directory to search (default: current directory) |
| `--help` / `-h` | no | — | print usage and exit |

- Wraps `find -iname`/`-name` (file names) and `grep -rn -I`/`-i` (file content, binary files skipped).

### `fixvscode`

Fixes VS Code on Linux drawing blank editor windows (stale Electron GPU/shader caches). Desktop only.

```
fixvscode
```

- Snapshots the open windows (`code --status`), quits VS Code gracefully (hot exit keeps unsaved edits), deletes only the GPU/shader cache folders under `~/.config/Code`, then relaunches it; VS Code restores every window.
- Run it from a standalone terminal, not VS Code's integrated one: quitting VS Code would kill the shell running the script.

### `wsname`

Names (or renames) a VS Code workspace and makes that name, instead of the open file, show in the window title and dock. Desktop only, needs `jq`.

```
wsname                                   # the only *.code-workspace in the current folder
wsname foobar                            # same, renamed to foobar.code-workspace
wsname path/to/file.code-workspace foobar
```

- Sets `"window.title": "${rootName}"` in the workspace settings.

## utils

Everything else.

### `share-qr`
Prints a QR code for arbitrary text (e.g. a Wi-Fi password) directly in the terminal. Pass `--out` to save it as a PNG file instead.

```
share-qr 'some text with special chars like $ @ # !'
share-qr 'some text' --out wifi.png
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `<text>` | yes | string | positional argument, first non-flag arg |
| `--out` | no | file path | save as PNG instead of printing to terminal |
| `--help` / `-h` | no | — | print usage and exit |

- No `--out`: wraps `qrencode -t ANSIUTF8 -l H <text>` (prints to terminal, nothing saved to disk).
- With `--out file.png`: wraps `qrencode -o file.png -s 10 -l H <text>`.
- Text is passed straight to `qrencode` as a single argument (no shell involved), so special characters like `$ @ # ' "` don't need any escaping — just quote the whole argument in your shell (single quotes `'...'` are safest, they stop your shell from expanding `$vars` before the command ever sees them).

### `translate-text`
Translates a text with the DeepL API (`deepl-node`) and prints the result. The source language is auto-detected.

```
translate-text --input "Good morning, how are you?" --output IT
```

| Flag | Required | Value | Description |
|---|---|---|---|
| `--input` | yes | string | text to translate |
| `--output` | yes | language code | DeepL target language: `IT`, `ES`, `DE`, `FR`, ... English and Portuguese need the variant: `EN-US`/`EN-GB`, `PT-BR`/`PT-PT` |
| `--help` / `-h` | no | — | print usage and exit |

- Needs `DEEPL_API_KEY` from the shell, else from this repo's `.env` (only that key is read from it). `deepl-node` picks the endpoint from the key: one ending in `:fx` (DeepL API Free) goes to `api-free.deepl.com`, any other to `api.deepl.com`. Quotas depend on the DeepL plan, see your DeepL account.
- The text is sent to DeepL.

## infra

Short-lived servers: created for an event, destroyed after.

### `jitsi-vultr`
Creates a self-hosted Jitsi Meet server on Vultr and points a Cloudflare DNS record at it, or destroys both. The server installs Jitsi by itself on first boot (cloud-init runs `bin/infra/jitsi-install.sh`): docker-jitsi-meet, Let's Encrypt, hosts log in, guests join without an account once a host is in, lobby on.

```
jitsi-vultr create --url https://bitvero.mbotyha.com --name "Foo bar baz" --duration 5h
PLAN=vhp-2c-4gb jitsi-vultr create --url https://call.mbotyha.com --region br
SNAPSHOT=1 jitsi-vultr destroy --url https://bitvero.mbotyha.com   # snapshot, destroy, remove the DNS record
```

| Flag / env | Required | Value | Description |
|---|---|---|---|
| `create` / `destroy` | yes | — | create or destroy (`up` / `down` still work) |
| `--url` | no | `https://<sub>.<zone>` | server address, default `https://bitvero.mbotyha.com` (same as `SUBDOMAIN` / `ZONE` env) |
| `--name` | no | text | event name: the printed link is `https://<host>/<name as slug>` (`Foo bar baz` → `/foo-bar-baz`) |
| `--duration` | no | `<n>m`, `<n>h`, `<n>d` | `create` only (`90m`, `5h`, `2d`): tags the server `expires=<time>`, the `vm-reaper` Worker destroys server and DNS record when it is up, laptop on or off |
| `VULTR_API_KEY` | yes | key | Vultr: Account → API Access; env or `~/.config/mbotyha/secrets.env` |
| `CLOUDFLARE_API_TOKEN` | yes | token | Cloudflare token with Zone Read + DNS Edit on the zone; env or `~/.config/mbotyha/secrets.env` |
| `--provider` | no | `vultr` | default and only one for now |
| `--region` | no | `nl`, `br`, `it`, `de` or a Vultr region id | default `nl` (Amsterdam); `br` São Paulo, `it` Milan, `de` Frankfurt; same as `REGION` env |
| `PLAN` | no | Vultr plan id | default `vhp-4c-8gb` (~30 people with video); `vhp-2c-4gb` for ~10 |
| `LE_EMAIL` | no | email | Let's Encrypt notices, default `letsencrypt@agent.mbotyha.com` |
| `SSH_KEY_FILE` | no | path | public key put on the server, default `~/.ssh/id_rsa.pub` |
| `SNAPSHOT` | no | `1` | `destroy` only: snapshot before destroying |
| `REPLACE_DNS` | no | `1` | `create` only: overwrite an existing A record (refused by default); `destroy` deletes the record only if it still points at the server |
| `--help` / `-h` | no | — | print usage and exit |

- The server label is `<SUBDOMAIN>-jitsi`: `create` refuses if it already exists, `destroy` finds it by label.
- The install waits until the DNS record points at the server, then requests the certificate.
- The host password is generated on the server, root-only: `ssh root@<ip> cat /root/jitsi-host-pass`. Install log: `/root/jitsi-install.log`.
- Billing runs while the server exists, stopped or not: `destroy` after the event, or `--duration`.

### `vm-reaper` (Worker)
Cloudflare Worker in `workers/vm-reaper/`, cron every 5 minutes: destroys every Vultr server tagged `expires=<unix seconds>` once that time has passed, after deleting the A record named by its `fqdn=<host>` tag (only while it still points at the server). No storage: the deadline lives on the server. Works with the laptop off.

```
cd workers/vm-reaper && npx wrangler deploy        # once, and after changes
npx wrangler secret put VULTR_API_KEY              # Vultr key, API access control open to any IP
npx wrangler secret put CLOUDFLARE_API_TOKEN       # Zone Read + DNS Edit
node workers/vm-reaper/check.mjs                   # offline check with a fake API
```

## Setup from scratch (to replicate on a VPS)

1. **Node.js + npm** (via nvm, recommended):
   ```
   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
   nvm install --lts
   ```

2. **Clone this repo and run the installer**:
   ```
   git clone git@github.com:ara-peaha-ai/ai.git
   cd ai-cli
   ./install.sh
   ```
   See [Install and update](#install-and-update) for what it does.

3. **System tools** the commands shell out to (see [System requirements](#system-requirements) for which command needs what):
   ```
   sudo apt install ffmpeg imagemagick qrencode jq
   ```

4. **Browser (for `chatgpt-image`)** — only this command needs a browser; the download commands use `gallery-dl`.

   **Desktop / machine with a screen** — install any Chromium-family browser:
   ```
   sudo apt install chromium-browser      # or google-chrome-stable, or brave
   ```
   `chatgpt-image` picks the OS default browser if it's Chromium-family, otherwise the first of `chrome` / `chromium` / `brave` it finds. Force one with `AICLI_BROWSER` (env or `.env`):
   ```
   AICLI_BROWSER=chrome        # name: chrome | chromium | brave
   AICLI_BROWSER=/opt/whatever/chrome   # or an absolute path
   ```

   **Headless host / VPS** — no local browser, use [browserless.io](https://www.browserless.io):
   1. Copy `.env.example` to `.env` and set `BROWSERLESS_API_KEY` (from the browserless dashboard). Optional: `BROWSERLESS_URL` to change region, or `BROWSERLESS_WS_ENDPOINT` for a self-hosted/tokenless endpoint. `.env` is git-ignored; the shell environment works too.
   2. On a desktop, run `chatgpt-image --dump-cookies` — log in when the window opens; it writes `bin/ai/chatgpt-cookies.json`.
   3. Copy that file to the host at the same path (or set `CHATGPT_COOKIES_FILE`). Re-run `--dump-cookies` and re-copy whenever the session expires.

   With no `DISPLAY` and `BROWSERLESS_API_KEY` set, the browserless path is used automatically. Check any machine with `ai-cli doctor`.

5. **gallery-dl**, via `pipx` (isolated from system Python, easy to upgrade):
   ```
   sudo apt install pipx
   pipx install gallery-dl
   pipx inject gallery-dl secretstorage   # required to decrypt Chrome's cookie store on Linux
   pipx ensurepath   # makes sure ~/.local/bin is on PATH, then reopen the shell
   ```
   To upgrade later: `pipx upgrade gallery-dl`.

   Note: `yt-dlp` was tried first (it's the better-known tool), but its Instagram extractors (both single-post and profile listing) are currently broken upstream — confirmed on the latest version. `gallery-dl` handles photos, reels, and profile batches correctly as of this writing.

6. **Authentication**:
   - `chatgpt-image` with a **local browser**: a persistent profile at `bin/ai/chrome-profile-chatgpt/` (created on first run); if not logged in, a **visible** window opens for a hand login (up to 5 min), then it continues. With **browserless / a headless host**: it can't keep a profile over a remote connection, so it loads `bin/ai/chatgpt-cookies.json` — see step 4. Alternative to browserless on a VPS: do the first login on a desktop and copy the whole `bin/ai/chrome-profile-chatgpt/` folder over, then a locally-installed headless Chromium runs from there with no display.
   - `instagram-download*`, `tiktok-download*`, and `x-download*` use `gallery-dl --cookies-from-browser chrome`, which reads cookies from the system's *default* Chrome profile (the one you use daily, already logged into Instagram/TikTok/X). Without `secretstorage` installed (step 5), cookie decryption silently fails for most cookies and requests get redirected to the login page even though you're actually logged in in Chrome — if you see login-redirect errors, check that `secretstorage` is injected into the `gallery-dl` pipx venv. **`--cookies-from-browser` also doesn't work out of the box on a display-less VPS with no locally logged-in Chrome.** Practical workaround: export cookies from your local Chrome into a `cookies.txt` file (e.g. with the "Get cookies.txt LOCALLY" extension), copy it to the VPS, and swap `--cookies-from-browser chrome` for `--cookies /path/to/cookies.txt` in the scripts — not implemented yet, do this if/when the VPS move actually happens.

## Install and update

```
./install.sh               # everything below
./install.sh --with-face   # also build the enhance-face stack (~2 GB)
./install.sh --with-bg-video   # also build the remove-bg-video stack (~1 GB)
./install.sh --help
```

`install.sh` is safe to re-run. It:

1. runs `npm install` and `npm link`, which registers every entry of `bin` in `package.json` as a global command (bash and Python scripts included, not only Node);
2. removes global command links left dangling by renamed or removed commands;
3. sets `git config core.hooksPath .githooks`, so after every `git pull` that changes `package.json`, `package-lock.json` or `install.sh`, the `post-merge` hook re-runs `./install.sh` by itself;
4. adds one line to `~/.bashrc` that sources [`shell/aliases.sh`](#shell-aliases) (only once);
5. registers the Claude Code hooks: `ai-resume` (open chats), `gitpool-landed --hook` (pushes that landed while no session was watching) and `workspace-check --hook` (warns when a session starts where the workspace's merge rule is not loaded);
6. when the `os` repo sits next to `ai` in the project folder, runs its `scripts/link-skills.sh` (framework skills into `~/.claude/skills`) and `scripts/link-project-settings.mjs <project>` (agent permissions into `<project>/.claude/settings.json`), so one install covers both repos;
7. with `--with-github-events`, or when `~/.peaha/github-events.env` already exists, deploys the `github-events` Worker and webhooks (see [`github-events-setup`](#github-events-setup)).

Edits to an existing script need nothing: the global commands are symlinks into this repo, so the change is live right away. A **new** command needs an entry in `bin` in `package.json`; the hook (or `./install.sh`) picks it up.

The commands are linked into the global bin folder of the current Node version. After `nvm install` of a new Node version, run `./install.sh` again.

### Server install (planned)

The same `install.sh` is meant to become the one entry point for a VPS, in the style of the BTCPay Server installer: a cloud-init `user-data` script pasted in the provider's form clones the repo and runs `./install.sh` with flags that pick which parts to set up (the way BTCPay uses `BTCPAYGEN_*` fragments and pruning options). Today the optional parts are `--with-face` and `--with-bg-video`; new parts get added as new `--with-*` flags, so existing installs keep working unchanged.

### Shell aliases

`shell/aliases.sh`, sourced from `~/.bashrc`:

| Alias / function | What it does |
|---|---|
| `t <name>` | Sets a fixed title on the current terminal tab |
| `aig <name>` | `t` + starts Grok |
| `rgcode <pattern>` | `rg` skipping `node_modules`, `.git`, `dist`, `build`, `venv`, `__pycache__`, `.next` |
| `killproton` | Force-kills ProtonVPN |
| `killfolder` / `killnautilus` | Force-kills the file manager (Nautilus) |

### Named desktop workspaces (optional, manual)

One desktop workspace per project, each with a name. Not part of `install.sh`: desktop setups differ too much, so this is a by-hand step. Not to be confused with [`wsname`](#wsname), which names VS Code workspaces.

**GNOME (X11 and Wayland)**

1. Fix the number of workspaces (GNOME adds and removes them on the fly by default, so a name could point to a workspace that does not exist), then set the names; order = workspace 1, 2, 3:
   ```
   gsettings set org.gnome.mutter dynamic-workspaces false
   gsettings set org.gnome.desktop.wm.preferences num-workspaces 3
   gsettings set org.gnome.desktop.wm.preferences workspace-names "['project-a', 'project-b', 'project-c']"
   ```
2. Install the official GNOME extensions package, then reload GNOME Shell (X11: `Alt+F2`, type `r`, Enter; Wayland: log out and back in):
   ```
   sudo apt install gnome-shell-extensions
   ```
3. Enable Workspace Indicator:
   ```
   gnome-extensions enable workspace-indicator@gnome-shell-extensions.gcampax.github.com
   ```
   On version 42 (Ubuntu / Pop!_OS 22.04) it never puts the name in the bar: with vertical workspaces (Pop!_OS) or more than 6 of them, the bar shows the number and a click opens the list of names; otherwise it shows small thumbnails, with the name on hover. Newer versions changed this; check the extension's settings.
4. For the name itself in the bar, install Extension Manager (`sudo apt install gnome-shell-extension-manager`), add **Space Bar** from its Browse tab (it lists only versions that fit your GNOME), then disable Workspace Indicator.

GNOME cannot show the names on the overview thumbnails.

**Open a project's apps on its workspace (X11 only)**

Needs `wmctrl` (`sudo apt install wmctrl`). Add to your own `~/.bashrc`, adapting paths and apps:

```
# gows <index> <dir>: switch to workspace <index> (0-based), open VS Code and a terminal there
gows() { wmctrl -s "$1" && sleep 0.2; code -n "$2"; gnome-terminal --working-directory="$2"; }
```

e.g. `gows 0 ~/code/project-a`. The short pause lets the switch finish before the windows open. A folder already open in VS Code is not opened again: VS Code focuses its existing window, on whatever workspace it sits.

Other desktops: stock GNOME on Wayland has no command line for it (only extensions that expose D-Bus, or `ydotool` sending the workspace shortcut); KDE (`qdbus`), Sway/i3 (`swaymsg`/`i3-msg`) and Hyprland (`hyprctl`) have their own; macOS needs a third-party tool such as AeroSpace.

### System requirements

All commands support `--help` / `-h`. `aspect-ratio` (also `ffprobe`), `get-first-frame`, `get-last-frame`, `blur-video`, `text-overlay`, `watermark`, `slideshow`, and `webp-to-jpg`/`image-to-jpg` (for `.webp` input) additionally require `ffmpeg` on `PATH` (`sudo apt install ffmpeg`). `upscale`, `heic-to-jpg`, and `image-to-jpg` (for `.heic`/`.heif`/`.avif` input) require `convert` from ImageMagick on `PATH` (`sudo apt install imagemagick`) — built with HEIC support (check with `convert -list format | grep -i heic`; if missing, install `libheif-dev` before ImageMagick, or use a distro package that bundles it). `chatgpt-image` and `create-virtual-ambassador` require a Chromium-family browser on the machine **or** a browserless.io endpoint (`BROWSERLESS_API_KEY`) — see setup step 4. `watermark` and `slideshow` require the `sharp` npm dependency (installed via `npm install`, no system package needed); `slideshow --fill` also uses `onnxruntime-node` (CPU only: `.npmrc` skips its ~280 MB CUDA/TensorRT download) and fetches its two models (~20 MB) on first use. `redact-faces` requires Sightengine API credentials (flags or env vars, see above). `share-qr` requires `qrencode` on `PATH` (`sudo apt install qrencode`). `search-string` requires `find` and `grep` on `PATH` (present by default on Linux). The `instagram-*`, `tiktok-*` and `x-*` commands need `gallery-dl` (setup step 5). `repo-split-branches` / `repo-join-branches` need `git` with SSH access to GitHub. `enhance-face` needs Python 3 with `venv`, `curl` and ~2 GB of disk (`./install.sh --with-face`). `remove-bg-video` needs Python 3.10–3.13 with `venv`, `curl`, `ffmpeg` + `ffprobe` with `libvpx-vp9` and `libopus` and ~1 GB of disk (`./install.sh --with-bg-video`). `wsname` needs `jq`; `ai-resume` needs `claude`, `jq` and `gnome-terminal`.

## Scraper status

Checked on 2026-10-04 with `gallery-dl` 1.32.13-dev.

| Platform | Status | Notes |
|---|---|---|
| TikTok | works | Single video download and profile listing work with Chrome cookies. `yt-dlp` does **not** work for TikTok profiles without impersonation (`pipx inject yt-dlp curl-cffi`), which is why these commands use `gallery-dl`. Profile listing pages through every post before downloading, so large profiles take a while to start. |
| Instagram | not re-checked | Needs `secretstorage` injected into the `gallery-dl` venv (setup step 5), or the requests get redirected to the login page. |
| X | not re-checked | |

## Repo structure

```
ai-cli/
├── install.sh                      # install / update everything (see "Install and update")
├── .githooks/post-merge            # re-runs install.sh after a pull that changes the command list
├── shell/aliases.sh                # shell aliases, sourced from ~/.bashrc
├── .env.example                    # browser / browserless / API env vars (copy to .env)
├── bin/
│   ├── ai-cli.js                   # command: ai-cli (lists all commands; `ai-cli doctor`)
│   ├── lib/                        # shared code: browser.js, chatgpt-session.js, sort-media.js, subject-crop.js
│   ├── ai/                         # chatgpt-image, create-virtual-ambassador, enhance-face, redact-faces, remove-bg-video
│   │   ├── chrome-profile-chatgpt/ # persistent browser profile (ChatGPT login) — git-ignored
│   │   └── chatgpt-cookies.json    # ChatGPT cookies for the browserless path — git-ignored
│   ├── social/                     # instagram-*, tiktok-*, x-* downloaders
│   ├── media/                      # image conversion, upscale, watermarks, video frames/blur/overlay/aspect ratio, slideshow
│   ├── dev/                        # ai-resume, gitchat, gitpush, gitpool-landed, github-events, workspace-check, repo-split-branches, repo-join-branches, search-string, fixvscode, wsname
│   ├── infra/                      # jitsi-vultr (+ jitsi-install.sh, run on the server by cloud-init)
│   └── utils/                      # share-qr, translate-text
├── workers/github-events/          # Cloudflare Worker behind github-events
├── .claude/skills/ffmpeg-skill/    # vendored third-party skill (MIT), see "media"
├── package.json                    # `bin`: command name -> script, read by npm link
└── README.md
```

Each command is one file, named after the command (`.js`, `.sh` or `.py`). To add one: drop the file in the right area folder, make it executable, add it to `bin` in `package.json` and to the list in `bin/ai-cli.js`.

## Todo

##todo @giovanni

- this repo becomes the ai-server (to distinguish from the pay-server) and the existing tools a small part of it. oppure no, rimane quello che 
- add languagetool selfhosted o meglio https://github.com/rayliuca/grammared-language con intregato modello ai leggero. 

##todo @ai

- From the Grok review of PR #6, not fixed there because they need a live ChatGPT / platform run to verify: `create-virtual-ambassador` waits only for an 8s idle gap (may keep 1 of 3 images), names variants by network order, matches a stale refusal from the reopened chat, and uploads faces to quantilence.com without asking; the batch downloaders look for the avatar only at the top of the output folder and flatten subfolders by basename (same name in two highlights overwrites); `enhance-face-setup.sh` has unpinned pip packages and no weight checksums.
