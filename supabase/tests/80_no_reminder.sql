-- 0011
insert into contacts(user_id,name,frequency_value,frequency_unit)
 values ('00000000-0000-0000-0000-00000000000c','Sans rappel',1,'never');
select 'never_due' as k, next_due_date is null as no_due from contacts where name='Sans rappel';
