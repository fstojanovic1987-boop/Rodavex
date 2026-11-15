-- RODAVEX v0.3 — Supabase schema
-- Run this whole file in Supabase Dashboard > SQL Editor > New query.
-- Uses one JSONB fleet snapshot per organization; local browser data is preserved until explicit upload.

create extension if not exists pgcrypto;

create table if not exists public.rodavex_organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 120),
  owner_id uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table if not exists public.rodavex_members (
  organization_id uuid not null references public.rodavex_organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'owner' check (role in ('owner','admin','manager','driver','viewer')),
  created_at timestamptz not null default now(),
  primary key (organization_id, user_id)
);

create table if not exists public.rodavex_fleet_data (
  organization_id uuid primary key references public.rodavex_organizations(id) on delete cascade,
  payload jsonb not null default '{"vehicles":[],"services":[]}'::jsonb,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint payload_shape check (
    jsonb_typeof(payload) = 'object'
    and jsonb_typeof(payload->'vehicles') = 'array'
    and jsonb_typeof(payload->'services') = 'array'
  )
);

create or replace function public.rodavex_create_organization(p_name text)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare new_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_name is null or char_length(trim(p_name)) < 2 or char_length(trim(p_name)) > 120 then
    raise exception 'Organization name must be 2–120 characters';
  end if;
  insert into public.rodavex_organizations(name, owner_id)
  values (trim(p_name), auth.uid()) returning id into new_id;
  insert into public.rodavex_members(organization_id, user_id, role)
  values (new_id, auth.uid(), 'owner');
  return new_id;
end;
$$;

alter table public.rodavex_organizations enable row level security;
alter table public.rodavex_members enable row level security;
alter table public.rodavex_fleet_data enable row level security;

-- SECURITY DEFINER helpers avoid recursive membership-policy evaluation.
create or replace function public.rodavex_is_member(p_org uuid)
returns boolean language sql stable security definer set search_path = public, auth
as $$ select exists (select 1 from public.rodavex_members m where m.organization_id = p_org and m.user_id = auth.uid()) $$;

create or replace function public.rodavex_has_role(p_org uuid, p_roles text[])
returns boolean language sql stable security definer set search_path = public, auth
as $$ select exists (select 1 from public.rodavex_members m where m.organization_id = p_org and m.user_id = auth.uid() and m.role = any(p_roles)) $$;

-- Organization members can see their organizations.
drop policy if exists "members can view organizations" on public.rodavex_organizations;
create policy "members can view organizations" on public.rodavex_organizations
for select to authenticated using (public.rodavex_is_member(id));

-- Users can see their own membership rows; owners/admins can manage memberships.
drop policy if exists "members can view memberships" on public.rodavex_members;
create policy "members can view memberships" on public.rodavex_members
for select to authenticated using (user_id = auth.uid() or public.rodavex_has_role(organization_id, array['owner','admin']));
drop policy if exists "owners can add members" on public.rodavex_members;
create policy "owners can add members" on public.rodavex_members
for insert to authenticated with check (public.rodavex_has_role(organization_id, array['owner','admin']));
drop policy if exists "owners can remove members" on public.rodavex_members;
create policy "owners can remove members" on public.rodavex_members
for delete to authenticated using (public.rodavex_has_role(organization_id, array['owner','admin']));

-- A signed-in member can read/write the shared fleet snapshot for their organization.
drop policy if exists "members can read fleet data" on public.rodavex_fleet_data;
create policy "members can read fleet data" on public.rodavex_fleet_data
for select to authenticated using (public.rodavex_is_member(organization_id));
drop policy if exists "managers can insert fleet data" on public.rodavex_fleet_data;
create policy "managers can insert fleet data" on public.rodavex_fleet_data
for insert to authenticated with check (updated_by = auth.uid() and public.rodavex_has_role(organization_id, array['owner','admin','manager']));
drop policy if exists "managers can update fleet data" on public.rodavex_fleet_data;
create policy "managers can update fleet data" on public.rodavex_fleet_data
for update to authenticated using (public.rodavex_has_role(organization_id, array['owner','admin','manager']))
with check (updated_by = auth.uid() and public.rodavex_has_role(organization_id, array['owner','admin','manager']));

grant usage on schema public to authenticated;
grant select on public.rodavex_organizations, public.rodavex_members, public.rodavex_fleet_data to authenticated;
grant insert, delete on public.rodavex_members to authenticated;
grant insert, update on public.rodavex_fleet_data to authenticated;
grant execute on function public.rodavex_create_organization(text) to authenticated;
grant execute on function public.rodavex_is_member(uuid) to authenticated;
grant execute on function public.rodavex_has_role(uuid, text[]) to authenticated;
