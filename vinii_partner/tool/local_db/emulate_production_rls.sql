-- LOCAL DEVELOPMENT ONLY. Never run against production.
--
-- The One Local dev stack's database (docker "supabase_db_onelocal-dev") is a
-- structure-only replica of the POS tables with the pilot restaurant's menu.
-- It has row-level security switched ON but no policies, because One Local's
-- server reads it with the service role. A staff member signing in to VINII
-- Partner therefore sees nothing locally, unlike production.
--
-- This script copies production's member policies (Repo-1- migrations
-- 0001, 0004, 0006, 0010) onto the tables VINII Partner reads, so the app
-- can be tested exactly as a staff member sees production. Additive and
-- idempotent: it only affects the `authenticated` role, which One Local's
-- server does not use. Remove with emulate_production_rls_undo.sql.
--
-- Apply:  docker exec -i supabase_db_onelocal-dev psql -U postgres -d postgres < tool/local_db/emulate_production_rls.sql

begin;

-- Production 0004: "your organization" = one active membership (gap G1 in
-- docs/PLATFORM_CONTRACT_ALIGNMENT.md — kept as production has it).
create or replace function public.current_org_id()
returns uuid language sql stable security definer set search_path = public, pg_temp as $$
  select organization_id from public.org_users
  where user_id = auth.uid() and status = 'active'
  limit 1;
$$;
grant execute on function public.current_org_id() to authenticated;

-- Roles are reference data (0004).
drop policy if exists roles_read on public.roles;
create policy roles_read on public.roles for select to authenticated using (true);

-- Memberships (0004): members see their organization's members.
drop policy if exists org_users_member_select on public.org_users;
create policy org_users_member_select on public.org_users for select
  using (organization_id = public.current_org_id());

-- Organizations (0004): a member reads every organization they belong to.
drop policy if exists organizations_member_select on public.organizations;
create policy organizations_member_select on public.organizations for select
  using (exists (select 1 from public.org_users u
                 where u.organization_id = organizations.id and u.user_id = auth.uid() and u.status = 'active'));

-- Organization-scoped tables (0006 / 0010 apply_org_rls shape).
do $$
declare t text;
begin
  foreach t in array array['menu_categories', 'menu_items', 'orders', 'kot_tickets', 'order_events', 'payments',
                           'item_channel_status', 'channel_integrations'] loop
    execute format('drop policy if exists %1$s_member_select on public.%1$s', t);
    execute format('drop policy if exists %1$s_member_insert on public.%1$s', t);
    execute format('drop policy if exists %1$s_member_update on public.%1$s', t);
    execute format('create policy %1$s_member_select on public.%1$s for select using (organization_id = public.current_org_id())', t);
    execute format('create policy %1$s_member_insert on public.%1$s for insert with check (organization_id = public.current_org_id())', t);
    execute format('create policy %1$s_member_update on public.%1$s for update using (organization_id = public.current_org_id()) with check (organization_id = public.current_org_id())', t);
  end loop;
  -- Menus may be deleted by members in production (0006).
  foreach t in array array['menu_categories', 'menu_items'] loop
    execute format('drop policy if exists %1$s_member_delete on public.%1$s', t);
    execute format('create policy %1$s_member_delete on public.%1$s for delete using (organization_id = public.current_org_id())', t);
  end loop;
end $$;

-- Order lines follow their order (0006).
drop policy if exists order_items_member_select on public.order_items;
create policy order_items_member_select on public.order_items for select
  using (exists (select 1 from public.orders o where o.id = order_items.order_id and o.organization_id = public.current_org_id()));

commit;
