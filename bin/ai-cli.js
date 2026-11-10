#!/usr/bin/env node

// `ai-cli doctor` — show which browser chatgpt-image would use right now.
if (process.argv[2] === 'doctor') {
  const path = require('path');
  try {
    process.loadEnvFile(path.join(__dirname, '..', '.env'));
  } catch {}
  const { resolveBrowser, isHeadlessBox } = require('./lib/browser');
  console.log(`headless host: ${isHeadlessBox() ? 'yes (no DISPLAY/WAYLAND)' : 'no'}`);
  try {
    const p = resolveBrowser();
    console.log(`browser      : ${p.mode === 'remote' ? 'remote — ' : 'local — '}${p.label}`);
  } catch (e) {
    console.log(`browser      : none — ${e.message}`);
    process.exit(1);
  }
  process.exit(0);
}

const AREAS = [
  ['ai', [
    ['ai', 'One entry point: ai claude|grok|deepseek <prompt>, ai ats < json, ai local <command> (any unique prefix)'],
    ['ai-bridge', 'HTTP door (Bearer token) to the JSON commands of ai, e.g. POST /ats'],
    ['chatgpt-image', 'Upload an image to ChatGPT with a prompt, download the result'],
    ['create-virtual-ambassador', 'Derive an avatar from reference photos via ChatGPT image generation'],
    ['enhance-face', 'Restore/upscale faces in a portrait with GFPGAN (CPU, needs --with-face setup)'],
    ['redact-faces', 'Blur/redact faces in an image or video via the Sightengine API'],
    ['remove-bg-video', 'Cut people out of a video, transparent WebM (CPU, needs --with-bg-video setup)'],
  ]],
  ['social', [
    ['instagram-download', 'Download a single Instagram reel, post, or photo'],
    ['instagram-download-batch', 'Download every post + story highlight from an Instagram profile'],
    ['tiktok-download', 'Download a single TikTok video or photo post'],
    ['tiktok-download-batch', 'Download every post from a TikTok profile'],
    ['x-download', 'Download a single X (Twitter) post\'s media'],
    ['x-download-batch', 'Download every media post from an X (Twitter) profile'],
  ]],
  ['media', [
    ['image-to-jpg', 'Convert any supported image format (.webp, .heic, .heif, .avif) to .jpg'],
    ['heic-to-jpg', 'Convert an iPhone .heic/.heif image (or a folder of them) to .jpg'],
    ['webp-to-jpg', 'Convert a .webp image (or a folder of them) to .jpg'],
    ['upscale', 'Resample an image (or a folder of images) up by an integer factor'],
    ['watermark', 'Tile a text watermark over images and videos (a file, a folder or the current folder)'],
    ['text-overlay', 'Draw a line of text over an image or a video'],
    ['aspect-ratio', 'Crop an image or a video to 16:9, 9:16, 4:3, 3:4, 1:1 or any x:y'],
    ['get-first-frame', 'Extract the first frame of a video as a JPEG'],
    ['get-last-frame', 'Extract the last frame of a video as a JPEG'],
    ['blur-video', 'Blur a video from a given second to the end'],
    ['slideshow', 'Merge images and videos (a folder or a list of files) into one silent mp4'],
  ]],
  ['dev', [
    ['ai-resume', 'Reopen the AI sessions a shutdown or crash killed, one terminal tab each (= ai resume)'],
    ['gitchat', 'Open a named Claude Code session for this folder, resuming it if it exists'],
    ['gitpush', 'Run a push an AI agent prepared in the project gitpool (.gitpool/<repo>/<id>)'],
    ['github-events', 'Print GitHub events (push, review, checks, comments) live, one JSON line each'],
    ['gitpool-landed', 'List the agent-prepared pushes that landed (also a SessionStart hook)'],
    ['github-events-setup', 'Deploy the github-events Cloudflare Worker and point the GitHub webhooks at it'],
    ['repo-split-branches', 'Check out every branch of a repo into its own worktree folder'],
    ['repo-join-branches', 'Fold the worktree folders back, saving uncommitted work as wip commits'],
    ['search-string', 'Search file names + content for a string in a directory'],
    ['fixvscode', 'Fix blank VS Code windows by clearing its GPU caches (desktop)'],
    ['wsname', 'Name a VS Code workspace and show it in the window title (desktop)'],
  ]],
  ['infra', [
    ['jitsi', 'Create or destroy a self-hosted Jitsi server (Vultr for now), DNS on Cloudflare'],
  ]],
  ['utils', [
    ['share-qr', 'Print/save a QR code for arbitrary text'],
    ['translate-text', 'Translate a text with DeepL: translate-text --input "text" --output IT'],
  ]],
];

const width = Math.max(...AREAS.flatMap(([, cmds]) => cmds.map(([name]) => name.length)));

console.log('Usage: ai-cli --help | -h');
console.log('       <command> --help   (each command below is its own CLI, run it directly)');
for (const [area, cmds] of AREAS) {
  console.log('');
  console.log(`${area}:`);
  for (const [name, desc] of cmds) {
    console.log(`  ${name.padEnd(width)}  ${desc}`);
  }
}
console.log('');
console.log('ai-cli doctor   Show which browser chatgpt-image would use');
console.log('Full docs: README.md');
