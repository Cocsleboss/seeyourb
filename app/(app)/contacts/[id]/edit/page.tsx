"use client";

import { useParams, useRouter } from "next/navigation";
import { ContactForm } from "@/components/contacts/ContactForm";
import { EmptyState, LinkButton, Page, PageLoader, TopBar, useToast } from "@/components/ui";
import { getContact } from "@/lib/data";
import { useAsyncData } from "@/lib/hooks";

export default function EditContactPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const toast = useToast();
  const { data: contact, loading } = useAsyncData(() => getContact(id), [id]);

  return (
    <>
      <TopBar title="Modifier le contact" back={`/contacts/${id}`} />
      <Page>
        {loading && !contact ? (
          <PageLoader />
        ) : !contact ? (
          <EmptyState title="Contact introuvable" action={<LinkButton href="/contacts">Voir mes contacts</LinkButton>} />
        ) : (
          <ContactForm
            initial={contact}
            onSaved={(c) => {
              toast.success("Contact mis à jour");
              router.replace(`/contacts/${c.id}`);
            }}
          />
        )}
      </Page>
    </>
  );
}
