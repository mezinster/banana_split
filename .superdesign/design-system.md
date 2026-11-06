# Banana Split — Design System (modernized, same identity)

## Product context
Banana Split splits a secret (seed phrase, master password) into N printable QR-code shards using Shamir's Secret Sharing; any quorum K of them plus a hand-written passphrase reconstructs it. Ships as ONE self-contained offline HTML file — no network, no fonts or images loaded from CDNs in the real app. All crypto is local.

Audience: privacy-conscious individuals doing paper backups; often restoring on a phone using the camera. Tone: calm, trustworthy, plain-spoken, a little playful (the banana).

### Key pages & JTBD
- `/` Info — understand what this is, trust it, pick an action (Create / Restore / Print).
- `/share` Create — 4 steps: 1. name, 2. secret (≤1024 chars, live counter), 3. shards (require any K out of N, defaults majority), 4. recovery passphrase (auto 4 words shown on a canvas with ↺ regenerate, or custom ≥8 chars via checkbox) → "Generate QR codes!" → QR grid + "Print us!" + print-language flag picker + "Back to editing".
- `/combine` Restore — scan shards (camera default; upload image(s); paste JSON) with progress "k of K"; then passphrase → reconstructed secret (read-only) .
- `/print` — re-print existing shards: enter count, rescan, print.
- Print output (one QR per A4 page, title, "need N more", blank line for the hand-written passphrase) is NOT being redesigned — keep it plain black-on-white.

## Identity (keep)
- Wordmark: "Banana Split" in bold + 🍌 emoji. There is no image logo; never invent one.
- Neutral warm-grey canvas, white surfaces, near-black text, hot-pink accent `#ff1864`.
- 9 languages incl. Cyrillic and Georgian — long strings must wrap; never fixed-width buttons.
- Language picker = flag emoji button with dropdown (flag + native name).
- Small "Fork me on GitHub 🥄" link and italic git revision in the footer.

## Tokens
Base font-size 16px (replace the old 9px root).

Light:
- `--bg` #f2f1f0 · `--surface` #ffffff · `--surface-muted` #f7f6f5
- `--text` #222222 · `--text-secondary` #606060 · `--text-muted` #8a8a8a
- `--border` #d6d6d6 · `--border-light` #ebebeb
- `--emphasis` #353535 (primary button bg) · `--emphasis-hover` #000000 · `--on-emphasis` #ffffff
- `--accent` #ff1864 (links, focus ring, active step, progress fill) · `--accent-soft` #ffe3ec
- `--success` #2e7d32 / bg #e8f5e9 · `--warn` #8b6400 / bg #ffe7b3 / border #e8b173 · `--danger` #b3261e / bg #ffdad6 / border #e87f73

Dark (prefers-color-scheme): `--bg` #161616 · `--surface` #222222 · `--surface-muted` #2a2a2a · `--text` #eeeeee · `--text-secondary` #b0b0b0 · `--border` #3a3a3a · `--emphasis` #f2f1f0 · `--on-emphasis` #161616 · accent unchanged. QR codes always render black on a white tile, in both themes.

Typography: system stack only (`-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif`) — no web fonts. Monospace (`ui-monospace, SFMono-Regular, Menlo, monospace`) for the passphrase and pasted shard JSON.
- Display 28/34 600 (-0.02em) · H2 22/28 600 · Body 16/24 · Label 14/20 500 secondary · Caption 13/18 muted.

Spacing: 4-based scale 4, 8, 12, 16, 24, 32, 48. Mobile gutter 16px. Content max-width 620px.
Radius: 12px cards, 10px buttons/inputs, 999px pills/chips. Shadow: `0 1px 2px rgba(0,0,0,.06), 0 8px 24px rgba(0,0,0,.06)` for cards; none in dark mode (use border).
Motion: 150–200ms ease-out for hover/focus; QR tile "unblur" reveal 600ms when a shard is scanned. Respect prefers-reduced-motion.

## Components
- **Header**: wordmark left, flag language button right, 56px tall, no background.
- **Card**: surface, 12px radius, 24px padding (16px on mobile), optional header row with title + step count.
- **Step / form section**: numbered circle (24px, accent when active/complete, border when pending) + label; replaces "1." prefixes inside labels.
- **Buttons**: Primary = emphasis bg, on-emphasis text, 48px tall, full-width on mobile. Secondary = surface + 1px border. Ghost/link = text-secondary, underline on hover. Icon button = 40px square. Disabled = 40% opacity. Focus = 2px accent ring with 2px offset.
- **Inputs**: 48px tall, 10px radius, 1px border, accent focus ring; error state = danger border + message below. Number steppers for shard counts (− value +).
- **Segmented control**: for ShardInput modes (Camera | Upload | Paste) and for Auto | Custom passphrase.
- **Progress**: "2 of 3 shards scanned" with K dots/segments and a slim accent bar.
- **QR tile**: white tile, 12px radius, border, shard number caption; placeholder variant = dashed border + blurred QR at 40% opacity.
- **Alert**: inline banner, 12px radius, icon + text, warn/danger/success colors above.
- **Bottom/primary nav** (Info page): three large action cards (Create / Restore / Print) with emoji/icon, title and one-line description — not small pills.

## Rules
- Mobile-first (375px). Tap targets ≥ 44px. No horizontal scroll.
- Never show the secret or passphrase in large decorative type; the passphrase stays on a canvas-like monospace field.
- Use ONLY these colors/fonts. No gradients, no purple/neon, no illustrations, no stock imagery, no new logo.
