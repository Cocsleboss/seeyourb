"use client";

import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from "react";
import { ensureProfile, getProfile } from "@/lib/data";
import type { Profile } from "@/lib/types";

export interface SessionUser {
  id: string;
  email: string | null;
}

interface SessionContextValue {
  user: SessionUser;
  profile: Profile | null;
  setProfile: (p: Profile | null) => void;
  refreshProfile: () => Promise<void>;
}

const SessionContext = createContext<SessionContextValue | null>(null);

export function SessionProvider({ user, children }: { user: SessionUser; children: ReactNode }) {
  const [profile, setProfile] = useState<Profile | null>(null);

  useEffect(() => {
    let alive = true;
    ensureProfile(user)
      .then((p) => alive && setProfile(p))
      .catch((e) => console.error("profil", e));
    return () => {
      alive = false;
    };
  }, [user.id, user.email]); // eslint-disable-line react-hooks/exhaustive-deps

  const refreshProfile = useCallback(async () => {
    const p = await getProfile();
    setProfile(p);
  }, []);

  return (
    <SessionContext.Provider value={{ user, profile, setProfile, refreshProfile }}>{children}</SessionContext.Provider>
  );
}

export function useSession(): SessionContextValue {
  const ctx = useContext(SessionContext);
  if (!ctx) throw new Error("useSession doit être utilisé dans <SessionProvider>");
  return ctx;
}
