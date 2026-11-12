"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { Suspense } from "react";
import { RdvForm } from "@/components/rdv/RdvForm";
import { Page, PageLoader, TopBar, useToast } from "@/components/ui";

function NewRdvForm() {
  const router = useRouter();
  const toast = useToast();
  const params = useSearchParams();
  const contact = params.get("contact");
  return (
    <RdvForm
      preselectedContactIds={contact ? [contact] : []}
      onSaved={(rdv) => {
        toast.success(rdv.status === "valide" ? "Rencontre enregistrée" : "Rendez-vous planifié");
        router.replace(`/rdv/${rdv.id}`);
      }}
    />
  );
}

export default function NewRdvPage() {
  return (
    <>
      <TopBar title="Nouveau rendez-vous" back />
      <Page>
        <Suspense fallback={<PageLoader />}>
          <NewRdvForm />
        </Suspense>
      </Page>
    </>
  );
}
