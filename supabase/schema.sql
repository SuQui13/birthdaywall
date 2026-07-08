-- ─────────────────────────────────────────────────────────────
-- Birthday Wishes Wall · Phase 1 schema
-- Run this once in the Supabase SQL editor (Dashboard → SQL).
--
-- Security model: RLS is enabled with NO policies, so the public
-- anon key cannot touch the tables directly. All reads and writes
-- go through the SECURITY DEFINER functions below, which decide
-- exactly which columns leave the database. Gift amounts and host
-- tokens never reach a browser.
-- ─────────────────────────────────────────────────────────────

create extension if not exists pgcrypto;

-- ── Tables ───────────────────────────────────────────────────

create table if not exists events (
  id         uuid primary key default gen_random_uuid(),
  slug       text not null unique check (slug ~ '^[a-z0-9-]{3,60}$'),
  host_token uuid not null default gen_random_uuid(),
  honoree    text not null default '' check (char_length(honoree) <= 40),
  event_date date,
  pay_link   text not null default '' check (char_length(pay_link) <= 200),
  goal       numeric not null default 0 check (goal >= 0),
  locks_at   timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists wishes (
  id         uuid primary key default gen_random_uuid(),
  event_id   uuid not null references events(id) on delete cascade,
  name       text not null check (char_length(name) between 1 and 40),
  msg        text not null check (char_length(msg) between 1 and 300),
  cat        text not null check (cat in ('funny','sweet','inspiring')),
  photo      text check (photo is null
                         or (photo like 'data:image/%' and char_length(photo) <= 400000)),
  gift       boolean not null default false,
  amt        numeric not null default 0 check (amt >= 0),
  created_at timestamptz not null default now()
);

create index if not exists wishes_event_idx on wishes(event_id, created_at);

-- Deny all direct access from the public API.
alter table events enable row level security;
alter table wishes enable row level security;
revoke all on table events from anon, authenticated;
revoke all on table wishes from anon, authenticated;

-- ── Public (guest) functions ─────────────────────────────────

-- Event info safe to show any guest. Never exposes goal, amounts,
-- or the host token — only whether a goal exists.
create or replace function public_event(p_slug text)
returns table(honoree text, pay_link text, has_goal boolean, locked boolean, event_date date)
language sql security definer set search_path = public as $$
  select e.honoree,
         e.pay_link,
         e.goal > 0,
         (e.locks_at is not null and now() > e.locks_at),
         e.event_date
  from events e
  where e.slug = p_slug;
$$;

-- Wishes without the amt column.
create or replace function get_wishes(p_slug text)
returns table(id uuid, name text, msg text, cat text, photo text, gift boolean, created_at timestamptz)
language sql security definer set search_path = public as $$
  select w.id, w.name, w.msg, w.cat, w.photo, w.gift, w.created_at
  from wishes w
  join events e on e.id = w.event_id
  where e.slug = p_slug
  order by w.created_at desc;
$$;

-- Aggregate progress only: a capped percentage and a contributor
-- count. Raw amounts and the goal never leave the database.
create or replace function get_progress(p_slug text)
returns table(pct int, givers int)
language sql security definer set search_path = public as $$
  select case when e.goal > 0
              then least(100, floor(coalesce(sum(w.amt) filter (where w.gift), 0) / e.goal * 100))::int
              else null end,
         (count(*) filter (where w.gift))::int
  from events e
  left join wishes w on w.event_id = e.id
  where e.slug = p_slug
  group by e.goal;
$$;

create or replace function add_wish(
  p_slug text, p_name text, p_msg text, p_cat text,
  p_photo text, p_gift boolean, p_amt numeric)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_event events%rowtype;
  v_count int;
  v_id uuid;
begin
  select * into v_event from events where slug = p_slug;
  if not found then
    raise exception 'event not found';
  end if;
  if v_event.locks_at is not null and now() > v_event.locks_at then
    raise exception 'wall is locked';
  end if;
  if p_cat not in ('funny','sweet','inspiring') then
    raise exception 'unknown category';
  end if;

  select count(*) into v_count from wishes where event_id = v_event.id;
  if v_count >= 150 then
    raise exception 'wish limit reached';
  end if;

  -- Photo cap: past 75 photos the wish is kept but the photo dropped.
  if p_photo is not null then
    select count(*) into v_count
    from wishes where event_id = v_event.id and photo is not null;
    if v_count >= 75 then
      p_photo := null;
    end if;
  end if;

  insert into wishes(event_id, name, msg, cat, photo, gift, amt)
  values (v_event.id, trim(p_name), trim(p_msg), p_cat, p_photo,
          coalesce(p_gift, false),
          case when coalesce(p_gift, false)
               then greatest(coalesce(p_amt, 0), 0) else 0 end)
  returning id into v_id;
  return v_id;
end $$;

-- ── Host functions (require the host token) ──────────────────

create or replace function verify_host(p_slug text, p_token text)
returns boolean
language sql security definer set search_path = public as $$
  select exists(
    select 1 from events where slug = p_slug and host_token::text = p_token
  );
$$;

create or replace function get_host_settings(p_slug text, p_token text)
returns table(honoree text, pay_link text, goal numeric, event_date date, locks_at timestamptz)
language sql security definer set search_path = public as $$
  select e.honoree, e.pay_link, e.goal, e.event_date, e.locks_at
  from events e
  where e.slug = p_slug and e.host_token::text = p_token;
$$;

create or replace function update_settings(
  p_slug text, p_token text, p_honoree text, p_pay_link text, p_goal numeric)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_event events%rowtype;
begin
  select * into v_event
  from events where slug = p_slug and host_token::text = p_token;
  if not found then
    raise exception 'not authorised';
  end if;

  -- One-event enforcement: once wishes exist, the honoree name is
  -- fixed so a wall can't be recycled for a different celebration.
  if v_event.honoree <> ''
     and trim(coalesce(p_honoree, '')) <> v_event.honoree
     and exists(select 1 from wishes where event_id = v_event.id) then
    raise exception 'honoree is locked once wishes have been pinned';
  end if;

  update events
  set honoree  = trim(coalesce(p_honoree, '')),
      pay_link = trim(coalesce(p_pay_link, '')),
      goal     = greatest(coalesce(p_goal, 0), 0)
  where id = v_event.id;
end $$;

create or replace function delete_wish(p_slug text, p_token text, p_wish uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_event_id uuid;
begin
  select id into v_event_id
  from events where slug = p_slug and host_token::text = p_token;
  if not found then
    raise exception 'not authorised';
  end if;
  delete from wishes where id = p_wish and event_id = v_event_id;
end $$;

-- ── Grants ───────────────────────────────────────────────────

grant execute on function public_event(text)                                    to anon, authenticated;
grant execute on function get_wishes(text)                                      to anon, authenticated;
grant execute on function get_progress(text)                                    to anon, authenticated;
grant execute on function add_wish(text,text,text,text,text,boolean,numeric)    to anon, authenticated;
grant execute on function verify_host(text,text)                                to anon, authenticated;
grant execute on function get_host_settings(text,text)                          to anon, authenticated;
grant execute on function update_settings(text,text,text,text,numeric)          to anon, authenticated;
grant execute on function delete_wish(text,text,uuid)                           to anon, authenticated;

-- ─────────────────────────────────────────────────────────────
-- Creating an event (one per sale) — run in the SQL editor:
--
--   insert into events (slug, honoree, event_date, locks_at)
--   values ('maya-30', 'Maya', '2026-08-15',
--           timestamptz '2026-08-15' + interval '7 days')
--   returning slug, host_token;
--
-- Then send the buyer:
--   Guest link: https://YOUR-PAGE/?e=maya-30
--   Host link:  https://YOUR-PAGE/?e=maya-30&host=<host_token>
-- ─────────────────────────────────────────────────────────────
