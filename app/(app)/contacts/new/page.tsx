"use client";

import { useRouter } from "next/navigation";
import { ContactForm } from "@/components/contacts/ContactForm";
import { Page, TopBar, useToast } from "@/components/ui";

export default function NewContactPage() {
  const router = useRouter();
  const toast = useToast();
  return (
    <>
      <TopBar title="Nouveau contact" back="/contacts" />
      <Page>
        <ContactForm
          onSaved={(contact) => {
            toast.success("Contact ajouté");
            router.replace(`/contacts/${contact.id}`);
          }}
        />
      </Page>
    </>
  );
}
