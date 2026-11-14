"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { Suspense } from "react";
import { ContactForm } from "@/components/contacts/ContactForm";
import { Page, PageLoader, TopBar, useToast } from "@/components/ui";

function NewContactForm() {
  const router = useRouter();
  const toast = useToast();
  const params = useSearchParams();
  // Arrivée depuis l'écran Amis : contact pré-rempli et associé au compte de l'ami
  const friend = params.get("friend");
  return (
    <ContactForm
      defaults={{ name: params.get("name") ?? "", email: params.get("email") ?? "" }}
      linkedUserId={friend}
      onSaved={(contact) => {
        toast.success(friend ? "Contact ajouté et associé à votre ami" : "Contact ajouté");
        router.replace(`/contacts/${contact.id}`);
      }}
    />
  );
}

export default function NewContactPage() {
  return (
    <>
      <TopBar title="Nouveau contact" back="/contacts" />
      <Page>
        <Suspense fallback={<PageLoader />}>
          <NewContactForm />
        </Suspense>
      </Page>
    </>
  );
}
