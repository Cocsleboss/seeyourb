import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "SeeU",
    short_name: "SeeU",
    description: "Ne plus oublier les personnes qu'on aimerait revoir.",
    start_url: "/",
    scope: "/",
    display: "standalone",
    orientation: "portrait",
    background_color: "#f9fafb",
    theme_color: "#4f46e5",
    lang: "fr",
    categories: ["social", "productivity", "lifestyle"],
    icons: [
      { src: "/icons/icon-192.png", sizes: "192x192", type: "image/png" },
      { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png" },
      { src: "/icons/maskable-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
    shortcuts: [
      { name: "Nouveau rendez-vous", url: "/rdv/new", icons: [{ src: "/icons/icon-192.png", sizes: "192x192" }] },
      { name: "Nouveau contact", url: "/contacts/new", icons: [{ src: "/icons/icon-192.png", sizes: "192x192" }] },
    ],
  };
}
