-- Sòti MQ — schéma Supabase (profils, activités, participations, messages)

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  prenom text not null,
  commune text not null,
  interests text[] not null default '{}',
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;

create policy "profiles_select_all"
  on public.profiles for select
  to authenticated
  using (true);

create policy "profiles_insert_own"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id);

create policy "profiles_delete_own"
  on public.profiles for delete
  to authenticated
  using (auth.uid() = id);


create table public.activities (
  id uuid primary key default gen_random_uuid(),
  organisateur_id uuid not null references auth.users(id) on delete cascade,
  titre text not null,
  categorie text not null,
  commune text not null,
  lieu text not null,
  date date not null,
  heure time not null,
  places int not null default 6,
  description text not null default '',
  created_at timestamptz not null default now()
);
alter table public.activities enable row level security;

create policy "activities_select_all"
  on public.activities for select
  to authenticated
  using (true);

create policy "activities_insert_own"
  on public.activities for insert
  to authenticated
  with check (auth.uid() = organisateur_id);

create policy "activities_update_own"
  on public.activities for update
  to authenticated
  using (auth.uid() = organisateur_id);

create policy "activities_delete_own"
  on public.activities for delete
  to authenticated
  using (auth.uid() = organisateur_id);


create table public.participations (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.activities(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (activity_id, user_id)
);
alter table public.participations enable row level security;

create policy "participations_select_all"
  on public.participations for select
  to authenticated
  using (true);

create policy "participations_insert_own"
  on public.participations for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "participations_delete_own"
  on public.participations for delete
  to authenticated
  using (auth.uid() = user_id);


create table public.messages (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.activities(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);
alter table public.messages enable row level security;

create policy "messages_select_participants"
  on public.messages for select
  to authenticated
  using (
    exists (select 1 from public.participations p where p.activity_id = messages.activity_id and p.user_id = auth.uid())
    or exists (select 1 from public.activities a where a.id = messages.activity_id and a.organisateur_id = auth.uid())
  );

create policy "messages_insert_participants"
  on public.messages for insert
  to authenticated
  with check (
    auth.uid() = author_id
    and (
      exists (select 1 from public.participations p where p.activity_id = messages.activity_id and p.user_id = auth.uid())
      or exists (select 1 from public.activities a where a.id = messages.activity_id and a.organisateur_id = auth.uid())
    )
  );

create policy "messages_delete_own"
  on public.messages for delete
  to authenticated
  using (auth.uid() = author_id);

-- Mises à jour en direct pour le fil d'activités, les inscriptions et le chat
alter publication supabase_realtime add table public.activities;
alter publication supabase_realtime add table public.participations;
alter publication supabase_realtime add table public.messages;
