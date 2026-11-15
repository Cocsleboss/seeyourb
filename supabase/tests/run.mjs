import EmbeddedPostgres from 'embedded-postgres';
import pg from 'pg';
import fs from 'fs';
const dir = process.argv[2];
const files = process.argv.slice(3);
const db = new EmbeddedPostgres({ databaseDir: dir + '/data', user: 'postgres', password: 'pw', port: 54329, persistent: false });
await db.initialise(); await db.start();
const c = new pg.Client({ host: 'localhost', port: 54329, user: 'postgres', password: 'pw', database: 'postgres' });
await c.connect();
let failed = false;
for (const f of files) {
  try { const r = await c.query(fs.readFileSync(f, 'utf8')); 
    const res = Array.isArray(r) ? r : [r];
    for (const x of res) if (x.rows && x.rows.length && x.command === 'SELECT') console.log(f.split('/').pop(), JSON.stringify(x.rows));
    console.log('OK', f.split('/').pop()); }
  catch (e) { console.log('FAIL', f.split('/').pop(), e.message, e.position ? 'pos ' + e.position : '', e.where || ''); failed = true; break; }
}
await c.end(); await db.stop();
process.exit(failed ? 1 : 0);
