-- Run once on an existing CMS database to enable division coordinators.
alter table public.divisions
    add column if not exists coordinator_id uuid
    references public.users(id) on update cascade on delete set null;

drop policy if exists "coordinator can update own division name" on public.divisions;
create policy "coordinator can update own division name"
on public.divisions
for update
to authenticated
using (coordinator_id = auth.uid())
with check (coordinator_id = auth.uid());

create or replace function public.guard_division_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if not public.is_admin() and not public.is_event_chair(old.event_id) then
        if old.coordinator_id is distinct from auth.uid()
           or new.id is distinct from old.id
           or new.event_id is distinct from old.event_id
           or new.coordinator_id is distinct from old.coordinator_id
           or new.created_at is distinct from old.created_at then
            raise exception 'Coordinators may only edit their own division name';
        end if;
    end if;
    return new;
end;
$$;

drop trigger if exists divisions_guard_update on public.divisions;
create trigger divisions_guard_update
before update on public.divisions
for each row execute function public.guard_division_update();
