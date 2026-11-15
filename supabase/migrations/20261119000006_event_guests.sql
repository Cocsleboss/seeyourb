-- People without a SeeU account taking part in an event.
--
-- Contacts are private cards, but once someone attaches one of their contacts
-- (not linked to a SeeU account) to an event, the other members see that person's
-- name in the participant list, marked "pas sur SeeU". Only the name is shared.
-- Public events never expose them (members are strangers to each other).

create or replace function public.list_event_guests(p_event uuid)
returns table (contact_id uuid, name text, added_by uuid, added_by_name text, is_mine boolean)
language sql
stable
security definer
set search_path = public
as $$
  select case when r.user_id = auth.uid() then c.id end,
         c.name,
         r.user_id,
         coalesce(nullif(trim(p.display_name), ''), p.username, 'SeeU'),
         r.user_id = auth.uid()
  from public.rendezvous r
  join public.events e on e.id = r.event_id
  join public.contact_rendezvous cr on cr.rendezvous_id = r.id
  join public.contacts c on c.id = cr.contact_id
  left join public.profiles p on p.id = r.user_id
  where r.event_id = p_event
    and c.linked_user_id is null
    and r.rsvp is distinct from 'declined'
    and public.is_event_member(p_event, auth.uid())
    and (e.visibility <> 'public' or r.user_id = auth.uid())
    and not public.is_blocked(r.user_id, auth.uid())
  order by (r.user_id = auth.uid()) desc, lower(c.name)
  limit 300
$$;

revoke execute on function public.list_event_guests(uuid) from public, anon;
grant execute on function public.list_event_guests(uuid) to authenticated;
