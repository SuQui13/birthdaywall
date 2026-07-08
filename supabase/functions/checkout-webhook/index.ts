// Lemon Squeezy checkout webhook → one wall per order, links emailed
// to the buyer automatically.
//
// Flow: buyer pays on your Lemon Squeezy checkout → Lemon Squeezy
// calls this function → it creates the event row (with the service
// role key, which bypasses RLS) → it emails the buyer their guest
// and host links via Resend.
//
// Deploy:
//   supabase functions deploy checkout-webhook --no-verify-jwt
//
// Secrets (supabase secrets set KEY=value):
//   LS_WEBHOOK_SECRET   the signing secret you set on the Lemon Squeezy webhook
//   RESEND_API_KEY      from resend.com (free tier is plenty)
//   FROM_EMAIL          verified sender, e.g. walls@yourdomain.com
//   SITE_URL            where index.html is hosted, e.g. https://you.github.io/birthdaywall
//   (SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically)
//
// In Lemon Squeezy: Settings → Webhooks → add
//   https://YOURPROJECT.supabase.co/functions/v1/checkout-webhook
// with the same signing secret, subscribed to "order_created".

const SLUG_ALPHABET = 'abcdefghijklmnopqrstuvwxyz0123456789';

export function randomSlug(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(8));
  let s = 'wall-';
  for (const b of bytes) s += SLUG_ALPHABET[b % SLUG_ALPHABET.length];
  return s;
}

export async function verifySignature(rawBody: string, signatureHex: string, secret: string): Promise<boolean> {
  if (!secret || !signatureHex) return false;
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const mac = new Uint8Array(await crypto.subtle.sign('HMAC', key, enc.encode(rawBody)));
  const expected = [...mac].map((b) => b.toString(16).padStart(2, '0')).join('');
  // constant-time-ish comparison
  const given = signatureHex.toLowerCase();
  if (given.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) diff |= expected.charCodeAt(i) ^ given.charCodeAt(i);
  return diff === 0;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

export function buyerEmailHtml(guestLink: string, hostLink: string): string {
  return `
  <div style="font-family:Georgia,serif;max-width:560px;margin:0 auto;color:#24152D">
    <h1 style="color:#4A2F58">🎈 Your Birthday Wishes Wall is ready!</h1>
    <p>Thank you for your purchase. Your wall is live — here's how to use it:</p>
    <h3 style="color:#2E5F66">1 · Your host link (keep this private)</h3>
    <p><a href="${hostLink}">${hostLink}</a></p>
    <p>Open it and tap <strong>⚙️ Host setup</strong> to add the birthday person's
       name, and (optionally) a gift-kitty payment link and a secret goal.
       This link also unlocks the <strong>🎁 Reveal</strong> on the big day.</p>
    <h3 style="color:#2E5F66">2 · The guest link (share with everyone)</h3>
    <p><a href="${guestLink}">${guestLink}</a></p>
    <p>Send it to the guests — or open your host link and tap
       <strong>📣 Invite guests</strong> for a printable QR code.</p>
    <p style="color:#6E98A0;font-size:13px">Your wall stays open for 60 days,
       then becomes a read-only keepsake.</p>
  </div>`;
}

type Env = Record<string, string | undefined>;
type FetchFn = typeof fetch;

export async function handleWebhook(req: Request, env: Env, fetchFn: FetchFn): Promise<Response> {
  if (req.method !== 'POST') return new Response('method not allowed', { status: 405 });

  const raw = await req.text();
  const sig = req.headers.get('x-signature') ?? '';
  if (!(await verifySignature(raw, sig, env.LS_WEBHOOK_SECRET ?? ''))) {
    return new Response('invalid signature', { status: 401 });
  }

  let payload: any;
  try { payload = JSON.parse(raw); } catch { return new Response('bad json', { status: 400 }); }

  const eventName = payload?.meta?.event_name;
  if (eventName !== 'order_created') return json({ ok: true, skipped: eventName });

  const email = payload?.data?.attributes?.user_email;
  if (!email) return new Response('no buyer email in order', { status: 400 });

  // 1 · create the event
  const slug = randomSlug();
  const createRes = await fetchFn(`${env.SUPABASE_URL}/rest/v1/events`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: env.SUPABASE_SERVICE_ROLE_KEY ?? '',
      Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
      Prefer: 'return=representation',
    },
    body: JSON.stringify({
      slug,
      locks_at: new Date(Date.now() + 60 * 86400_000).toISOString(),
    }),
  });
  if (!createRes.ok) {
    return new Response('event creation failed: ' + await createRes.text(), { status: 500 });
  }
  const [event] = await createRes.json();

  // 2 · email the buyer their links
  const guestLink = `${env.SITE_URL}/?e=${slug}`;
  const hostLink = `${env.SITE_URL}/?e=${slug}&host=${event.host_token}`;
  const mailRes = await fetchFn('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${env.RESEND_API_KEY}`,
    },
    body: JSON.stringify({
      from: env.FROM_EMAIL,
      to: email,
      subject: '🎈 Your Birthday Wishes Wall is ready!',
      html: buyerEmailHtml(guestLink, hostLink),
    }),
  });
  if (!mailRes.ok) {
    // the event exists; surface the failure so Lemon Squeezy retries
    return new Response('email failed: ' + await mailRes.text(), { status: 500 });
  }

  return json({ ok: true, slug });
}

// deno-lint-ignore no-explicit-any
declare const Deno: any;
if (typeof Deno !== 'undefined' && Deno?.serve) {
  Deno.serve((req: Request) => handleWebhook(req, Deno.env.toObject(), fetch));
}
