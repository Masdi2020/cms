-- Jalankan setelah cms_supabase_full.sql di SQL Editor Supabase.
-- Semua operasi client memakai Supabase Auth + PostgREST; password hanya di auth.users.

-- Pengguna terautentikasi dapat ditemukan untuk penetapan ketua/PIC/anggota.
create policy "authenticated users can view directory" on public.users for select to authenticated using (true);
create policy "user can edit own profile" on public.users for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
revoke update on public.users from authenticated;
grant update (name, phone) on public.users to authenticated;

create policy "event users can view members" on public.members for select to authenticated
using (exists (select 1 from public.divisions d where d.id = division_id and public.can_access_event(d.event_id)));
create policy "chair can add members" on public.members for insert to authenticated
with check (public.can_manage_division(division_id));
create policy "chair can edit members" on public.members for update to authenticated
using (public.can_manage_division(division_id))
with check (public.can_manage_division(division_id));
create policy "chair can remove members" on public.members for delete to authenticated
using (public.can_manage_division(division_id));

create policy "event users can view attachments" on public.attachments for select to authenticated
using (public.can_access_task(task_id));
create policy "manager or assignee can insert attachment" on public.attachments for insert to authenticated
with check (uploaded_by = auth.uid() and exists (select 1 from public.tasks t where t.id = task_id and (public.can_manage_division(t.division_id) or t.assigned_to = auth.uid())));
create policy "manager or assignee can update attachment" on public.attachments for update to authenticated
using (exists (select 1 from public.tasks t where t.id = task_id and (public.can_manage_division(t.division_id) or t.assigned_to = auth.uid())))
with check (uploaded_by = auth.uid() and exists (select 1 from public.tasks t where t.id = task_id and (public.can_manage_division(t.division_id) or t.assigned_to = auth.uid())));
create policy "manager or assignee can delete attachment" on public.attachments for delete to authenticated
using (exists (select 1 from public.tasks t where t.id = task_id and (public.can_manage_division(t.division_id) or t.assigned_to = auth.uid())));

create policy "event users can view comments" on public.comments for select to authenticated
using (public.can_access_task(task_id));
create policy "event users can add comments" on public.comments for insert to authenticated
with check (user_id = auth.uid() and public.can_access_task(task_id));
create policy "author or manager can delete comments" on public.comments for delete to authenticated
using (user_id = auth.uid() or exists (select 1 from public.tasks t where t.id = task_id and public.can_manage_division(t.division_id)));

-- RLS tidak membatasi kolom UPDATE: cegah perubahan peran event oleh ketua
-- serta perubahan isi tugas oleh anggota yang hanya boleh mengubah status.
create or replace function public.guard_event_update() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.id is distinct from old.id then raise exception 'Event ID cannot change'; end if;
  if not public.is_admin() and new.ketua_panitia_id is distinct from old.ketua_panitia_id then
    raise exception 'Only an admin may assign the event chair';
  end if;
  return new;
end;
$$;
create trigger guard_event_update before update on public.events for each row execute function public.guard_event_update();

create or replace function public.guard_task_update() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if not public.can_manage_division(old.division_id) and (
    new.id is distinct from old.id or
    new.created_at is distinct from old.created_at or
    new.division_id is distinct from old.division_id or
    new.assigned_to is distinct from old.assigned_to or
    new.title is distinct from old.title or
    new.description is distinct from old.description or
    new.deadline is distinct from old.deadline or
    new.priority is distinct from old.priority
  ) then raise exception 'Assignees may only change task status'; end if;
  return new;
end;
$$;
create trigger guard_task_update before update on public.tasks for each row execute function public.guard_task_update();

-- Pastikan PIC merupakan anggota divisi yang dipilih.
create or replace function public.guard_task_assignee() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.assigned_to is not null and not exists (
    select 1 from public.members m where m.division_id = new.division_id and m.user_id = new.assigned_to
  ) then raise exception 'PIC must be a member of the task division'; end if;
  return new;
end;
$$;
create trigger guard_task_assignee before insert or update of assigned_to, division_id on public.tasks for each row execute function public.guard_task_assignee();

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('task-attachments', 'task-attachments', false, 10485760, array['image/jpeg','image/png','application/pdf'])
on conflict (id) do nothing;

create or replace function public.can_manage_attachment_path(p_name text) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.tasks t
    where t.id::text = split_part(p_name, '/', 1)
    and (public.can_manage_division(t.division_id) or t.assigned_to = auth.uid())
  );
$$;
create or replace function public.can_view_attachment_path(p_name text) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.tasks t
    where t.id::text = split_part(p_name, '/', 1)
    and public.can_access_task(t.id)
  );
$$;
create policy "event users can read task files" on storage.objects for select to authenticated
using (bucket_id = 'task-attachments' and public.can_view_attachment_path(name));
create policy "manager or assignee can upload task files" on storage.objects for insert to authenticated
with check (bucket_id = 'task-attachments' and public.can_manage_attachment_path(name));
create policy "manager or assignee can delete task files" on storage.objects for delete to authenticated
using (bucket_id = 'task-attachments' and public.can_manage_attachment_path(name));

alter table public.attachments add constraint attachments_link_scheme_check
check (type <> 'link' or url ~* '^https?://[^[:space:]]+$');
alter table public.attachments add constraint attachments_file_task_path_check
check (type <> 'file' or file_path like task_id::text || '/%');
