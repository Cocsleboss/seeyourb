-- =====================================================================
--  SeeU — migration 0009: account emails stay technical
--  * a contact card created automatically for a SeeU friend no longer gets
--    their account email
--  * a new account's default name is no longer made from its email
--  * cleanup: removes friends' account emails already copied onto cards
--  * avatars: owners can list their own files (needed to delete old pictures)
-- =====================================================================

create or replace function public.ensure_friend_contact(p_user uuid, p_friend uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_contact uuid := public.copy_contact_for(p_user, p_friend);
  sender public.profiles%rowtype;
begin
  if v_contact is null and public.are_friends(p_user, p_friend) then
    select * into sender from public.profiles where id = p_friend;
    insert into public.contacts (user_id, name, frequency_value, frequency_unit, linked_user_id)
    values (
      p_user,
      left(coalesce(nullif(trim(sender.display_name), ''), sender.username, 'SeeU'), 120),
      1, 'months', p_friend
    )
    returning id into v_contact;
  end if;
  return v_contact;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_username text := lower(trim(leading '@' from trim(coalesce(new.raw_user_meta_data ->> 'username', ''))));
  v_locale text := lower(coalesce(new.raw_user_meta_data ->> 'locale', ''));
  v_name text;
begin
  if v_username !~ '^[a-z0-9][a-z0-9_.]{2,19}$'
     or exists (select 1 from public.profiles where username = v_username) then
    v_username := null;
  end if;
  if v_locale !~ '^[a-z]{2}$' then v_locale := 'fr'; end if;
  -- never derived from the email: the profile screen asks for a name anyway
  v_name := coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''), v_username);
  begin
    insert into public.profiles (id, email, display_name, username, locale)
    values (new.id, new.email, v_name, v_username, v_locale)
    on conflict (id) do update set email = excluded.email;
  exception when unique_violation then
    insert into public.profiles (id, email, display_name, locale)
    values (new.id, new.email, v_name, v_locale)
    on conflict (id) do update set email = excluded.email;
  end;
  return new;
end;
$$;

update public.contacts c
set email = null
from public.profiles p
where p.id = c.linked_user_id and c.email is not null and lower(c.email) = lower(p.email);

drop policy if exists "avatars_select_own" on storage.objects;
create policy "avatars_select_own" on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
