import { redirect } from "next/navigation";
import { BottomNav } from "@/components/BottomNav";
import { ProfileGate } from "@/components/ProfileGate";
import { SessionProvider } from "@/lib/session";
import { getServerUser } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  if (!process.env.NEXT_PUBLIC_SUPABASE_URL || !process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY) {
    redirect("/login");
  }
  const { user } = await getServerUser();
  if (!user) redirect("/login");

  return (
    <SessionProvider user={{ id: user.id, email: user.email ?? null }}>
      <ProfileGate>
        <div className="min-h-dvh pb-[calc(5rem+env(safe-area-inset-bottom))]">{children}</div>
        <BottomNav />
      </ProfileGate>
    </SessionProvider>
  );
}
