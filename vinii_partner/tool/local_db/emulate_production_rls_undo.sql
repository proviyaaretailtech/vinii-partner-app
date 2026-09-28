-- LOCAL DEVELOPMENT ONLY. Removes what emulate_production_rls.sql added,
-- returning the One Local dev replica to "RLS on, no policies".
begin;
drop policy if exists roles_read on public.roles;
drop policy if exists org_users_member_select on public.org_users;
drop policy if exists organizations_member_select on public.organizations;
do $$
declare t text;
begin
  foreach t in array array['menu_categories', 'menu_items', 'orders', 'kot_tickets', 'order_events', 'payments',
                           'item_channel_status', 'channel_integrations'] loop
    execute format('drop policy if exists %1$s_member_select on public.%1$s', t);
    execute format('drop policy if exists %1$s_member_insert on public.%1$s', t);
    execute format('drop policy if exists %1$s_member_update on public.%1$s', t);
    execute format('drop policy if exists %1$s_member_delete on public.%1$s', t);
  end loop;
end $$;
drop policy if exists order_items_member_select on public.order_items;
drop function if exists public.current_org_id();
commit;
