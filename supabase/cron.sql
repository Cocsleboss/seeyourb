-- =====================================================================
--  SeeYourB — tâche planifiée (pg_cron + pg_net, inclus gratuitement
--  dans Supabase). Toutes les 10 minutes, Supabase appelle l'API de
--  l'application qui envoie les rappels (push, puis email en secours).
--
--  À exécuter APRÈS le déploiement sur Vercel, en remplaçant :
--    1) VOTRE-APP.vercel.app   → l'URL de votre déploiement (sans slash final)
--    2) VOTRE_CRON_SECRET      → la valeur de CRON_SECRET définie sur Vercel
--
--  Supabase → SQL Editor → New query → coller → Run
-- =====================================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Supprime l'ancienne version de la tâche si elle existe (relançable sans erreur)
do $$
begin
  if exists (select 1 from cron.job where jobname = 'seeyourb-tick') then
    perform cron.unschedule('seeyourb-tick');
  end if;
end
$$;

select cron.schedule(
  'seeyourb-tick',
  '*/10 * * * *',
  $cron$
  select net.http_post(
    url := 'https://VOTRE-APP.vercel.app/api/cron/tick',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer VOTRE_CRON_SECRET'
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000
  );
  $cron$
);

-- Vérifications utiles :
--   select jobid, jobname, schedule, active from cron.job;
--   select status, return_message, start_time from cron.job_run_details order by start_time desc limit 10;
--   select id, status_code, content::text from net._http_response order by id desc limit 5;
