"use client";

import { useParams, useRouter } from "next/navigation";
import { RdvForm } from "@/components/rdv/RdvForm";
import { EmptyState, LinkButton, Page, PageLoader, TopBar, useToast } from "@/components/ui";
import { getRdv } from "@/lib/data";
import { useAsyncData } from "@/lib/hooks";

export default function EditRdvPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const toast = useToast();
  const { data: rdv, loading } = useAsyncData(() => getRdv(id), [id]);

  return (
    <>
      <TopBar title="Modifier le rendez-vous" back={`/rdv/${id}`} />
      <Page>
        {loading && !rdv ? (
          <PageLoader />
        ) : !rdv ? (
          <EmptyState title="Rendez-vous introuvable" action={<LinkButton href="/">Retour à l'accueil</LinkButton>} />
        ) : (
          <RdvForm
            initial={rdv}
            onSaved={(r) => {
              toast.success("Rendez-vous mis à jour");
              router.replace(`/rdv/${r.id}`);
            }}
          />
        )}
      </Page>
    </>
  );
}
