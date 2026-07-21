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


create table public.reports (
  id uuid primary key default gen_random_uuid(),
  signalant_id uuid not null references auth.users(id) on delete cascade,
  cible_type text not null check (cible_type in ('activite', 'profil', 'message')),
  cible_id uuid not null,
  motif text not null,
  detail text,
  statut text not null default 'nouveau' check (statut in ('nouveau', 'traite', 'classe_sans_suite')),
  created_at timestamptz not null default now()
);
alter table public.reports enable row level security;

-- Chaque membre peut créer un signalement en son nom.
create policy "reports_insert_own"
  on public.reports for insert
  to authenticated
  with check (auth.uid() = signalant_id);

-- Volontairement aucune policy de lecture pour les membres : seul le
-- propriétaire du projet (via le tableau de bord Supabase, qui contourne
-- la RLS) peut consulter les signalements tant qu'il n'y a pas de
-- back-office de modération dédié.

-- Mises à jour en direct pour le fil d'activités, les inscriptions et le chat
alter publication supabase_realtime add table public.activities;
alter publication supabase_realtime add table public.participations;
alter publication supabase_realtime add table public.messages;


-- ===================== Modération : statut de compte + rôle admin =====================

alter table public.profiles add column statut text not null default 'actif' check (statut in ('actif', 'suspendu', 'banni'));
alter table public.profiles add column is_admin boolean not null default false;

create or replace function public.is_admin() returns boolean
language sql stable
as $$ select coalesce((select is_admin from public.profiles where id = auth.uid()), false); $$;

create or replace function public.is_active() returns boolean
language sql stable
as $$ select coalesce((select statut = 'actif' from public.profiles where id = auth.uid()), false); $$;

-- L'admin peut modifier n'importe quel profil (changer son statut notamment).
create policy "profiles_update_admin"
  on public.profiles for update
  to authenticated
  using (public.is_admin());

-- L'admin peut lire et traiter les signalements.
create policy "reports_select_admin"
  on public.reports for select
  to authenticated
  using (public.is_admin());

create policy "reports_update_admin"
  on public.reports for update
  to authenticated
  using (public.is_admin());

-- Un compte suspendu ou banni ne peut plus créer de sortie, s'inscrire ni écrire de message.
drop policy "activities_insert_own" on public.activities;
create policy "activities_insert_own"
  on public.activities for insert
  to authenticated
  with check (auth.uid() = organisateur_id and public.is_active());

drop policy "participations_insert_own" on public.participations;
create policy "participations_insert_own"
  on public.participations for insert
  to authenticated
  with check (auth.uid() = user_id and public.is_active());

drop policy "messages_insert_participants" on public.messages;
create policy "messages_insert_participants"
  on public.messages for insert
  to authenticated
  with check (
    auth.uid() = author_id
    and public.is_active()
    and (
      exists (select 1 from public.participations p where p.activity_id = messages.activity_id and p.user_id = auth.uid())
      or exists (select 1 from public.activities a where a.id = messages.activity_id and a.organisateur_id = auth.uid())
    )
  );

-- Pour désigner un administrateur (à exécuter une fois, en remplaçant l'e-mail) :
-- update public.profiles set is_admin = true
--   where id = (select id from auth.users where email = 'votre-email@exemple.com');


-- ===================== Profil enrichi : âge, bio, photo =====================

alter table public.profiles add column age int check (age is null or age >= 18);
alter table public.profiles add column bio text not null default '' check (char_length(bio) <= 280);
alter table public.profiles add column avatar_url text;

-- Bucket de stockage pour les photos de profil (public en lecture).
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy "avatars_public_read"
  on storage.objects for select
  to public
  using (bucket_id = 'avatars');

create policy "avatars_insert_own"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "avatars_update_own"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "avatars_delete_own"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);


-- ===================== Liste d'attente automatique =====================

alter table public.participations add column statut text not null default 'inscrit' check (statut in ('inscrit', 'liste_attente'));

create or replace function public.promote_waitlist() returns trigger
language plpgsql security definer
as $$
declare
  v_places int;
  v_inscrits int;
  v_next_id uuid;
begin
  select places into v_places from public.activities where id = old.activity_id;
  if v_places is null then
    return old;
  end if;
  select count(*) into v_inscrits from public.participations where activity_id = old.activity_id and statut = 'inscrit';
  if v_inscrits < v_places then
    select id into v_next_id from public.participations
      where activity_id = old.activity_id and statut = 'liste_attente'
      order by created_at asc limit 1;
    if v_next_id is not null then
      update public.participations set statut = 'inscrit' where id = v_next_id;
    end if;
  end if;
  return old;
end;
$$;

create trigger trg_promote_waitlist
  after delete on public.participations
  for each row execute function public.promote_waitlist();


-- ===================== Filtrage de contenu sensible dans les messages =====================
-- Filet de sécurité côté base (en plus du contrôle côté application) : bloque
-- les liens externes et les motifs ressemblant à des coordonnées bancaires.

alter table public.messages add constraint messages_no_sensitive_content check (
  content !~* '(https?://|www\.[a-z0-9-]+\.[a-z]{2,})'
  and content !~ '([0-9][ -]?){13,19}'
  and content !~* '\b[a-z]{2}[0-9]{2}[a-z0-9]{10,30}\b'
);


-- ===================== Chat réservé aux participants confirmés =====================
-- Les membres en liste d'attente ne doivent plus lire ni écrire dans le
-- chat de groupe tant qu'ils ne sont pas passés "inscrit".

drop policy "messages_select_participants" on public.messages;
create policy "messages_select_participants"
  on public.messages for select
  to authenticated
  using (
    exists (select 1 from public.participations p where p.activity_id = messages.activity_id and p.user_id = auth.uid() and p.statut = 'inscrit')
    or exists (select 1 from public.activities a where a.id = messages.activity_id and a.organisateur_id = auth.uid())
  );

drop policy "messages_insert_participants" on public.messages;
create policy "messages_insert_participants"
  on public.messages for insert
  to authenticated
  with check (
    auth.uid() = author_id
    and public.is_active()
    and (
      exists (select 1 from public.participations p where p.activity_id = messages.activity_id and p.user_id = auth.uid() and p.statut = 'inscrit')
      or exists (select 1 from public.activities a where a.id = messages.activity_id and a.organisateur_id = auth.uid())
    )
  );


-- ===================== Sorties en visio =====================

alter table public.activities add column en_ligne boolean not null default false;
