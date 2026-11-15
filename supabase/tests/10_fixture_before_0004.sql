-- State before 0004: 3 users, a & b friends, one rdv shared a→b (accepted), one solo rdv.
insert into vault.secrets values ('project_url','https://x.supabase.co'),('dispatch_secret','s');
insert into auth.users(id, email, raw_user_meta_data) values
 ('00000000-0000-0000-0000-00000000000a','andrea@x.fr','{"username":"andrea","display_name":"Andrea"}'),
 ('00000000-0000-0000-0000-00000000000b','marie@x.fr','{"username":"marie","display_name":"Marie"}'),
 ('00000000-0000-0000-0000-00000000000c','chris@x.fr','{"username":"chris","display_name":"Chris","locale":"en"}');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000a', false);
select send_friend_request('marie') ->> 'status' as req;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000b', false);
select send_friend_request('andrea') ->> 'status' as back;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000a', false);
insert into contacts(id,user_id,name,frequency_value,frequency_unit,linked_user_id)
 values ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-00000000000a','Marie',1,'months','00000000-0000-0000-0000-00000000000b');
insert into rendezvous(id,user_id,title,appointment_at) values
 ('30000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-00000000000a','Poker', now() + interval '2 days'),
 ('30000000-0000-0000-0000-000000000009','00000000-0000-0000-0000-00000000000a','Solo', now() - interval '2 days');
insert into contact_rendezvous values ('10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-00000000000a');
select send_rdv_invite('30000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-00000000000b') is not null as invited;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000b', false);
select respond_rdv_invite((select id from rdv_invitations limit 1), 'accepted') is not null as accepted;
select set_config('request.jwt.claim.sub','', false);
