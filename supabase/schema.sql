-- ============================================================
-- Tunnfly – Supabase Schema
-- Run this in the Supabase SQL editor to set up your database
-- ============================================================

-- ── Profiles ────────────────────────────────────────────────
-- Extends auth.users. Public key is the X25519 public key
-- used for E2E key exchange. Private key NEVER leaves the device.
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  username    text unique not null,
  public_key  text not null,           -- base64-encoded X25519 public key
  created_at  timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Anyone authenticated can read profiles (needed to start a conversation)
create policy "Profiles are readable by authenticated users"
  on public.profiles for select
  using (auth.role() = 'authenticated');

-- Insert is handled exclusively by the trigger below (no direct client insert)
-- Update is allowed by the authenticated owner (e.g. new device re-key)
create policy "Users update their own profile"
  on public.profiles for update
  using (auth.uid() = id);


-- ── Trigger: auto-create profile on sign up ──────────────────
-- The Flutter client passes username + public_key as user metadata.
-- This trigger runs with SECURITY DEFINER so it bypasses RLS,
-- which means it works regardless of whether email confirmation is on.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username, public_key)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', 'user_' || substr(new.id::text, 1, 8)),
    coalesce(new.raw_user_meta_data->>'public_key', '')
  );
  return new;
end;
$$;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- ── Conversations ────────────────────────────────────────────
create table if not exists public.conversations (
  id             uuid primary key default gen_random_uuid(),
  participant_1  uuid not null references public.profiles (id) on delete cascade,
  participant_2  uuid not null references public.profiles (id) on delete cascade,
  created_at     timestamptz not null default now(),
  -- Ensure participant_1 < participant_2 to prevent duplicates
  constraint participants_ordered check (participant_1 < participant_2),
  constraint unique_conversation unique (participant_1, participant_2)
);

alter table public.conversations enable row level security;

-- Users can only see their own conversations
create policy "Users see their own conversations"
  on public.conversations for select
  using (
    auth.uid() = participant_1 or auth.uid() = participant_2
  );

create policy "Users create conversations they participate in"
  on public.conversations for insert
  with check (
    auth.uid() = participant_1 or auth.uid() = participant_2
  );


-- ── Messages ─────────────────────────────────────────────────
-- Content is AES-256-GCM encrypted on the client.
-- The server only stores ciphertext — it cannot read messages.
create table if not exists public.messages (
  id                 uuid primary key default gen_random_uuid(),
  conversation_id    uuid not null references public.conversations (id) on delete cascade,
  sender_id          uuid not null references public.profiles (id) on delete cascade,
  encrypted_content  text not null,   -- base64(ciphertext || GCM tag)
  iv                 text not null,   -- base64(12-byte nonce)
  created_at         timestamptz not null default now()
);

alter table public.messages enable row level security;

-- Only participants of a conversation can read its messages
create policy "Participants read messages"
  on public.messages for select
  using (
    exists (
      select 1 from public.conversations c
      where c.id = conversation_id
        and (c.participant_1 = auth.uid() or c.participant_2 = auth.uid())
    )
  );

-- Only the sender can insert (and only if they're a participant)
create policy "Participants send messages"
  on public.messages for insert
  with check (
    auth.uid() = sender_id
    and exists (
      select 1 from public.conversations c
      where c.id = conversation_id
        and (c.participant_1 = auth.uid() or c.participant_2 = auth.uid())
    )
  );


-- Only the sender can delete their own messages
create policy "Users delete their own messages"
  on public.messages for delete
  using (auth.uid() = sender_id);


-- ── Realtime ─────────────────────────────────────────────────
-- Enable realtime for the messages table
alter publication supabase_realtime add table public.messages;
