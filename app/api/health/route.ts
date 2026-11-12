import { NextResponse } from "next/server";
import { emailProvider } from "@/lib/email";
import { pushConfigured } from "@/lib/notify";
import { getServerUser } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

/** Diagnostic de configuration (réservé aux utilisateurs connectés). */
export async function GET() {
  const { user } = await getServerUser();
  if (!user) return NextResponse.json({ error: "Non connecté" }, { status: 401 });
  return NextResponse.json({
    push: pushConfigured(),
    email: emailProvider(),
    cron: Boolean(process.env.CRON_SECRET),
    serviceRole: Boolean(process.env.SUPABASE_SERVICE_ROLE_KEY),
    appUrl: process.env.NEXT_PUBLIC_APP_URL || null,
  });
}
