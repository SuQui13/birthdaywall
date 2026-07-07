# 🎈 Birthday Wishes Wall

A festive, single-file web app for collecting birthday wishes at a celebration —
balloons, bunting, streamers, confetti and all.

## Features

- **Guest wishes** — guests pin a message with their name and a category
  (😂 Funny · 💖 Sweet · ✨ Inspiring), with category filters on the wall.
- **Photo upload** — optional photo per wish, downscaled in the browser so it
  fits in local storage.
- **Custom birthday person** — the host sets the birthday person's name in
  *⚙️ Host setup*; the title, subtitle, and reveal all address them by name.
- **Group gift kitty** — the host can add a payment link (PayPal.me, Bizum,
  Verse, bank note…) and a private goal. Guests tap *Chip in*, which opens the
  payment link — money flows directly through the payment provider, never
  through this page.
- **Amount-free progress** — the progress bar only ever shows a percentage and
  the number of contributors. The goal and all amounts stay secret.
- **Contributor symbol** — wishes from guests who chipped in carry a 🎁 next to
  their name (never the amount).
- **Reveal mode** — a full-screen experience for the birthday person: wishes
  unwrap one by one with pop-in animations and confetti, ending in a
  "Happy Birthday, {name}!" finale that credits every guest.

## Quick start

It's one file with zero dependencies:

1. Open `index.html` in any browser, **or** enable GitHub Pages
   (Settings → Pages → deploy from `main`) to host it online.
2. Tap **⚙️ Host setup** and enter the birthday person's name, and optionally a
   gift-kitty link and goal.
3. Hand the device around (or share the page URL) and let guests pin wishes.
4. On the big day, tap **🎁 Reveal for the Birthday Person**.

## How data is stored (important)

All wishes, photos, and settings live in the **browser's localStorage** of the
device viewing the page. That makes it perfect as a *party kiosk* — one shared
tablet/laptop that guests pass around — or as a personal page.

It also means:

- Guests visiting the hosted page on **their own phones each see their own
  wall**, not a shared one. A shared online wall needs a small backend
  (e.g. Supabase/Firebase) — see roadmap below.
- Gift amounts entered by guests are stored in plain text in localStorage of
  that device. They're never displayed, but anyone with the device could open
  developer tools and read them. Fine for a party; not for strangers.
- Clearing the browser's site data erases the wall. Export before that.

## Productizing roadmap

Ideas if you want to sell this as a service:

1. **Shared walls**: move wishes to a hosted database with one wall per event
   (unique link per celebration) so guests can post from their own phones.
2. **Real payments**: integrate Stripe Payment Links or PayPal checkout per
   event instead of a pasted link; payouts go to the host.
3. **Host accounts**: sign-in, event dashboard, moderation (approve/hide
   wishes), and a private view of the gift total.
4. **Extras**: themes, video wishes, QR-code invitations, printable keepsake
   book of all wishes.
