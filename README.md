# 🎈 Birthday Wishes Wall

A festive microapp for collecting birthday wishes at a celebration — balloons,
bunting, streamers, confetti and all. Sold **per event**: each purchase gets one
wall with its own link, its own birthday person, and its own group-gift kitty.

## Features

- **Guest wishes** — guests pin a message with their name and a category
  (😂 Funny · 💖 Sweet · ✨ Inspiring), plus an optional photo (downscaled in
  the browser before upload).
- **Custom birthday person** — the host sets the name; the title, subtitle and
  reveal all address them by name.
- **Four festive themes** — Classic (plum & gold), Pastel, Midnight (night sky
  with glowing cards), and Sunshine, picked by the host and applied for every
  guest instantly.
- **Keepsake book** — the host can print the whole wall (or save it as a PDF)
  as a clean book: cover page with the name and dates, then every wish and
  photo in order.
- **Group gift kitty** — the host adds a payment link (PayPal.me, Bizum,
  Verse, …) and a private goal. Guests tap *Chip in*, which opens the link —
  money flows directly through the payment provider, never through this app.
- **Amount-free progress** — guests only ever see a percentage and a
  contributor count. The goal and all amounts stay inside the database; the
  API physically never returns them.
- **Contributor symbol** — wishes from guests who chipped in carry a 🎁 next
  to their name (never the amount).
- **Reveal mode** — a full-screen experience for the birthday person: wishes
  unwrap one by one with confetti, ending in a "Happy Birthday, {name}!" finale.
- **Host vs guest links** — the host link (secret token) unlocks setup, the
  reveal, wish moderation, and an **📣 Invite guests** panel with a copyable
  guest link and a printable QR code; the guest link can only add wishes.
- **One event, enforced** — each wall has a unique slug, auto-locks after the
  event date (becoming a read-only keepsake), caps at 150 wishes / 75 photos,
  and the birthday person's name is fixed once wishes start arriving.
- **Seller console** — `admin.html` (guarded by an admin key) creates events,
  builds the buyer's links + QR, and lists every wall with wish counts and
  lock status. No SQL needed per sale.
- **Automated checkout** — an optional Supabase Edge Function turns a
  Lemon Squeezy purchase into a wall automatically and emails the buyer
  their links.

## Two modes

| | |
|---|---|
| **Demo mode** | Open `index.html` with no configuration — wishes live in that browser's localStorage. Perfect as the live demo on your sales page, or as a single-device party kiosk. |
| **Event mode** | With Supabase configured and `?e=<slug>` in the URL, everyone shares one wall — guests post from their own phones. This is what you sell. |

## Deploying (one-time, ~15 minutes)

1. **Create a Supabase project** (free tier) at [supabase.com](https://supabase.com).
2. In the dashboard, open **SQL Editor**, paste the contents of
   [`supabase/schema.sql`](supabase/schema.sql), and run it.
3. In **Project Settings → API**, copy the *Project URL* and the *anon public*
   key, and paste them into the two constants at the top of the `<script>`
   block in `index.html`:
   ```js
   const SUPABASE_URL='https://YOURPROJECT.supabase.co';
   const SUPABASE_ANON_KEY='eyJ…';
   ```
   (The anon key is designed to be public — the SQL schema locks down what it
   can do.)
4. Paste the same two constants into `admin.html`.
5. Set your seller **admin key** (a long random secret only you know) — in the
   SQL editor run:
   ```sql
   insert into seller_config (admin_key_hash)
   values (encode(digest('CHOOSE-A-LONG-RANDOM-SECRET', 'sha256'), 'hex'))
   on conflict (id) do update set admin_key_hash = excluded.admin_key_hash;
   ```
6. Host the files anywhere static — GitHub Pages (Settings → Pages → deploy
   from `main`) works free. `index.html`, `admin.html`, and `qr.js` live side
   by side.

## Selling manually (one sale ≈ one minute)

Open `admin.html`, unlock with your admin key, and fill in the *Create an
event* form (slug, optional name, event date). The console shows the buyer's
**guest link**, **host link**, and a QR code of the guest link — copy them into
your sale confirmation email. The buyer does the rest themselves via
**⚙️ Host setup** on their host link.

The console also lists every wall you've sold with wish counts and lock
status, and can re-surface any wall's links if a buyer loses them.

## Selling automatically (optional)

`supabase/functions/checkout-webhook/index.ts` turns a
[Lemon Squeezy](https://lemonsqueezy.com) purchase into a wall with zero
manual work: it verifies the webhook signature, creates the event (locked
60 days out), and emails the buyer both links via
[Resend](https://resend.com). Setup instructions are in the file header —
deploy with `supabase functions deploy checkout-webhook --no-verify-jwt` and
set the four secrets. Lemon Squeezy retries failed webhooks, and the function
returns 500 on any failure, so transient hiccups self-heal.

## Privacy model

- The database tables are fully closed to the public API key (row-level
  security with no policies). Every read and write goes through server-side
  functions that choose exactly which columns leave the database.
- Gift **amounts** and the **goal** are returned by no function. Guests' apps
  receive only `pct` (0–100, capped) and a contributor count — nothing to find
  in developer tools.
- The **host token** is only ever compared, never returned.
- Wishes are visible to anyone who has the guest link — say so on the wall's
  invite so guests know it's a shared space.

## Files

| | |
|---|---|
| `landing.html` | Buyer-facing sales page — features, pricing, FAQ, demo link |
| `index.html` | The wall — guest view, host view, and offline demo mode |
| `admin.html` | Seller console — create/list events, buyer links, QR codes |
| `qr.js` | QR encoder ([qrcode-generator](https://github.com/kazuhikoarase/qrcode-generator), MIT) |
| `supabase/schema.sql` | Tables, security model, and all API functions |
| `supabase/functions/checkout-webhook/` | Optional Lemon Squeezy → wall automation |

Point buyers at `landing.html`; its "Try the live demo" button opens the wall
in demo mode. Set `BUY_URL` (your checkout link) and `PRICE` at the bottom of
`landing.html` before going live.

## Roadmap

- Video wishes (needs Supabase Storage for uploads)
- Multi-language walls
- Per-theme printable invitation templates
