-- Run after cms_supabase_full.sql, cms_supabase_policies.sql, and
-- cms_username_login.sql. Safe to run again on an existing project.
-- Table grants allow PostgREST requests; RLS policies still decide which rows
-- each signed-in user may access.

grant usage on schema public to authenticated;

grant select on public.users to authenticated;
revoke update on public.users from authenticated;
grant update (name, phone, username) on public.users to authenticated;

grant select, insert, update, delete on
    public.events,
    public.divisions,
    public.members,
    public.tasks,
    public.attachments,
    public.comments
to authenticated;

-- Edge Functions using SUPABASE_SERVICE_ROLE_KEY bypass RLS, but PostgreSQL
-- still requires table privileges. Keep this key server-side only.
grant usage on schema public to service_role;
grant select, insert, update, delete on
    public.users,
    public.events,
    public.divisions,
    public.members,
    public.tasks,
    public.attachments,
    public.comments
to service_role;
grant usage, select on all sequences in schema public to service_role;
