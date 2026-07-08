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
  reveal, and wish moderation; the guest link can only add wishes.
- **One event, enforced** — each wall has a unique slug, auto-locks after the
  event date (becoming a read-only keepsake), caps at 150 wishes / 75 photos,
  and the birthday person's name is fixed once wishes start arriving.

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
4. Host `index.html` anywhere static — GitHub Pages (Settings → Pages → deploy
   from `main`) works free.

## Creating an event (one per sale, ~2 minutes)

In the Supabase **SQL Editor**, run:

```sql
insert into events (slug, honoree, event_date, locks_at)
values ('maya-30', 'Maya', '2026-08-15',
        timestamptz '2026-08-15' + interval '7 days')
returning slug, host_token;
```

Then email the buyer their two links:

- **Guest link** (share with everyone): `https://YOUR-PAGE/?e=maya-30`
- **Host link** (keep private): `https://YOUR-PAGE/?e=maya-30&host=<host_token>`

The host opens their link, taps **⚙️ Host setup**, and customizes the name,
gift-kitty link, and goal themselves — you don't have to do anything else.
`locks_at` is when the wall closes to new wishes and becomes a keepsake.

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

## Roadmap

- **Phase 2 — self-serve sales**: a checkout webhook (Lemon Squeezy / Paddle /
  Stripe) that runs the event insert automatically and emails the buyer their
  links, plus a QR code per event for invitations.
- **Phase 3 — polish**: theme picker, keepsake PDF export of all wishes after
  the event, video wishes.
