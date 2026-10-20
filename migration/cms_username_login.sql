-- Jalankan setelah cms_supabase_full.sql. Bisa dijalankan pada database lama.
alter table public.users add column if not exists username text;
create unique index if not exists users_username_unique
    on public.users (lower(username)) where username is not null;
update public.users
set username = lower(auth_user.raw_user_meta_data ->> 'username')
from auth.users as auth_user
where auth_user.id = public.users.id and public.users.username is null
  and auth_user.raw_user_meta_data ->> 'username' is not null;

revoke update on public.users from authenticated;
grant update (name, phone, username) on public.users to authenticated;

create or replace function public.email_for_username(p_username text)
returns text
language sql
security definer
set search_path = ''
stable
as $$
    select u.email
    from public.users as u
    where lower(u.username) = lower(trim(p_username))
    limit 1;
$$;

revoke all on function public.email_for_username(text) from public;
grant execute on function public.email_for_username(text) to anon, authenticated;
