-- =====================================================================
--  SeeU — migration 0011: contacts without recurring reminder
--  frequency_unit 'never': compute_next_due() has no case for it, so the
--  contact's next_due_date is null, and the digest / overdue counts (which
--  compare that date) skip it on their own. Birthdays still work.
-- =====================================================================
alter type public.frequency_unit add value if not exists 'never';
