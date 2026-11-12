// Génère une paire de clés VAPID pour le Web Push : npm run vapid
import webpush from "web-push";

const keys = webpush.generateVAPIDKeys();
console.log("\nAjoutez ces lignes à vos variables d'environnement (Vercel → Settings → Environment Variables) :\n");
console.log(`NEXT_PUBLIC_VAPID_PUBLIC_KEY=${keys.publicKey}`);
console.log(`VAPID_PRIVATE_KEY=${keys.privateKey}`);
console.log(`VAPID_SUBJECT=mailto:vous@exemple.com\n`);
