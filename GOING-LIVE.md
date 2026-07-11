# 🚀 Going live — the friendly walkthrough

This guide assumes **no technical experience**. Every step says exactly what
to click. Total time: about 45 minutes, all free.

You do the steps marked **YOU** (they need your accounts).
Claude does the steps marked **CLAUDE** (just paste the info into the chat).

---

## Step 1 — YOU: create the database (≈15 min)

The database is where guests' wishes are stored. We use Supabase (free).

1. Go to **supabase.com** and click **Start your project**.
2. Sign in with your GitHub account (easiest).
3. Click **New project**:
   - Name: `birthdaywall`
   - Database password: click *Generate a password* and **save it somewhere
     safe** (you rarely need it, but don't lose it).
   - Region: pick the one closest to you (e.g. *West EU*).
   - Click **Create new project** and wait ~2 minutes while it sets up.
4. In the left sidebar, click **SQL Editor**, then **New query**.
5. Open the file `supabase/schema.sql` from this repository
   (on GitHub: click the file → click the *copy raw contents* button, two
   squares icon). Paste **all of it** into the query box and press **Run**.
   You should see *"Success. No rows returned"*.
6. Now invent your **admin key** — a long made-up secret only you know, like a
   master password (example shape: `lila-moon-42-tambourine-syrup`). Write it
   down — you'll type it every time you open the seller console.
7. Back in the SQL Editor, click **New query** again, paste this — but replace
   `YOUR-SECRET-HERE` with your admin key — and press **Run**:

   ```sql
   insert into seller_config (admin_key_hash)
   values (encode(digest('YOUR-SECRET-HERE', 'sha256'), 'hex'))
   on conflict (id) do update set admin_key_hash = excluded.admin_key_hash;
   ```

8. In the left sidebar click the **gear icon (Project Settings) → API**.
   You'll see two things:
   - **Project URL** — looks like `https://abcdefgh.supabase.co`
   - **anon public** key — a very long string starting with `eyJ`

   Copy both.

## Step 2 — CLAUDE: wire the keys in

Paste the Project URL and the anon key into the chat. (The anon key is
*designed* to be public — sharing it is safe. Never share your admin key or
database password.) Claude puts them into `index.html` and `admin.html` and
pushes the change.

## Step 3 — YOU: turn on the website (≈5 min)

GitHub Pages turns this repository into a live website, free.

1. On github.com, open the **birthdaywall** repository.
2. If the repo is private: **Settings → General**, scroll to *Danger Zone* →
   **Change visibility → Make public**. (Everything in the repo is code that
   visitors' browsers download anyway — your admin key is never in it.)
3. **Settings → Pages** (left sidebar):
   - Source: **Deploy from a branch**
   - Branch: **main**, folder **/ (root)** → **Save**
4. Wait 2–3 minutes, refresh the page — GitHub shows your site address:
   `https://suqui13.github.io/birthdaywall/`

Tell Claude the address — the sales page and webhook use it.

## Step 4 — YOU + CLAUDE: dress rehearsal (≈15 min)

1. Open `https://…github.io/birthdaywall/admin.html`, type your admin key,
   click **Unlock**.
2. Create a test event (name: anyone, slug: `test-run`).
3. Open the **guest link** on your phone — pin a wish with a photo.
4. Open the **host link** — set a theme, a pretend gift goal, and try
   **📣 Invite guests** (scan the QR with another phone if you can).
5. Run **🎁 Reveal** and print the **📖 Keepsake**.

If anything looks wrong, tell Claude what you saw — that's what the rehearsal
is for.

## Step 5 — YOU: sell it (manual mode, start today)

1. Decide a price (€9–15 per event is the right neighbourhood).
2. List it wherever you already reach people — Etsy, Gumroad, Instagram, your
   website — and link to your landing page:
   `https://…github.io/birthdaywall/landing.html`
3. When someone buys: open `admin.html`, create their event (1 minute), and
   email them the two links the console shows you. Done.

## Later (optional) — automate the selling

When manual sales feel worth automating: create a Lemon Squeezy account
(they handle VAT and invoices for you) and a Resend account (sends the
emails), then ask Claude to walk you through deploying the checkout webhook —
after that, purchases create walls and email buyers with no work from you.
