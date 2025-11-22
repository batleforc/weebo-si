import { defineConfig, HeadConfig } from "vitepress";
import MermaidExample from "./mermaid-markdown-all.js";

/// Umami
const umamiScript: HeadConfig = [
  "script",
  {
    defer: "true",
    src: process.env.VITE_UMAMI_URL || "",
    "data-website-id": process.env.VITE_UMAMI_ID || "",
  },
];

const baseHeaders: HeadConfig[] = [];

const headers =
  process.env.NODE_ENV === "production"
    ? [...baseHeaders, umamiScript]
    : baseHeaders;

/// RSS
//const baseUrl = "https://batleforc.github.io";
//const RSS: RSSOptions = {
//  title: "Weebo-Env",
//  baseUrl,
//  copyright: `Copyright (c) 2025-present, Batleforc`,
//  authors: [
//    {
//      name: "Batleforc",
//      link: "https://github.com/batleforc",
//    },
//  ],
//};

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "Weebo SI",
  description:
    "The nearly perfect dev environment made to test new cool stuff and more",
  base: "/weebo-si/",
  head: headers,
  lastUpdated: true,
  markdown: {
    theme: {
      dark: "catppuccin-mocha",
      light: "catppuccin-latte",
    },
    config: (md) => {
      MermaidExample(md);
    },
  },
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    nav: [
      { text: "Home", link: "/" },
      { text: "Introduction", link: "/0.introduction/home" },
    ],

    editLink: {
      pattern: ({ filePath, frontmatter }) => {
        if (typeof frontmatter.editLink === "string") {
          return frontmatter.editLink;
        }
        return `https://github.com/batleforc/weebo-si/edit/main/docs/${filePath}`;
      },
      text: "Edit this page on GitHub",
    },
    outline: {
      level: "deep",
    },
    search: {
      provider: "local",
    },

    sidebar: [
      {
        text: "0. Introduction",
        items: [
          { text: "Introduction", link: "/0.introduction/home" },
          { text: "Sources", link: "/0.introduction/sources" },
          { text: "Contribuer", link: "/0.introduction/contributing" },
          { text: "Etape", link: "/0.introduction/etape" },
          { text: "Kanban", link: "/0.introduction/kanban" },
          {
            text: "Projects",
            collapsed: true,
            items: [
              { text: "Capi Vs Omni ?", link: "/0.projects/capi-vs-omni" },
              { text: "AllInOne Argo", link: "/0.projects/all-in-one" },
              {
                text: "ProxyAuthK8S",
                link: "/0.projects/reverse-api-kube-oidc-based",
              },
              {
                text: "WireChromium",
                link: "/0.projects/rs-wirechrome",
              },
              {
                text: "KAMALOS !",
                link: "/0.projects/kamalos",
              },
              {
                text: "Boot-C",
                link: "/0.projects/boot-c",
              },
            ],
          },
        ],
      },
      {
        text: "0. Setup",
        items: [
          {
            text: "Préparation du poste de travail",
            link: "/0.setup/prepare-pc",
          },
        ],
      },
      {
        text: "1. Kubevirt",
        items: [
          { text: "Architecture", link: "/1.Kubevirt/architecture" },
          {
            text: "1. Création de l'infrastructure",
            items: [
              {
                text: "Talos x Cilium sur OVH via Pulumi",
                link: "/1.Kubevirt/1.infrastructure/initOvhTalos",
              },
              {
                text: "Kubevirt sur Talos x Cilium via Argo",
                link: "/1.Kubevirt/1.infrastructure/installationKubevirt",
              },
              {
                text: "Cluster Api sur Talos x Cilium x Kubevirt",
                link: "/1.Kubevirt/1.infrastructure/installationCapi",
              },
              {
                text: "Kubevirt CSI sur Talos x Cluster API",
                link: "/1.Kubevirt/1.infrastructure/installationKubevirtCSI",
              },
              {
                text: "Eclipse Che sur Talos",
                link: "/1.Kubevirt/1.infrastructure/installationEclipseChe",
              },
            ],
          },
        ],
      },
      {
        text: "1. Proxmox",
        collapsed: true,
        items: [
          { text: "Architecture", link: "/1.Proxmox/architecture" },
          {
            text: "1. Création de l'infrastructure",
            items: [
              {
                text: "Préparation du serveur",
                link: "/1.Proxmox/1.infrastructure/prepare-server",
              },
              {
                text: "Préparation pour nos premières VM",
                link: "/1.Proxmox/1.infrastructure/prepare-first-vm",
              },
              {
                text: "Création de la première VM CAPI",
                link: "/1.Proxmox/1.infrastructure/creation-capi",
              },
            ],
          },
          {
            text: "2. Gestion de l'infrastructure",
            items: [
              {
                text: "Mise en place CAPI",
                link: "/1.Proxmox/2.gestion/capi",
              },
            ],
          },
        ],
      },
      {
        text: "3. Déployer des applications (MVP 1)",
      },
      {
        text: '4. Environnement de dev "Parfait" (MVP 2)',
      },
      {
        text: "5. User friendly",
      },
      {
        text: "6. Intégration (MVP 3)",
      },
      {
        text: "7. Aller plus loin",
        items: [
          {
            text: "Bilan des streams",
            items: [
              {
                text: "Saison 1",
                link: "/0.introduction/stream/saison1/index",
              },
              {
                text: "Saison 2",
                link: "/0.introduction/stream/saison2/index",
              },
            ],
          },
          {
            text: "User Story",
            collapsed: true,
            items: [
              {
                text: "us9 - Updatecli",
                link: "/0.us/us9",
              },
              {
                text: "us15 - Dns Dynamique",
                link: "/0.us/us15",
              },
              {
                text: "us16 - Certificat authority",
                link: "/0.us/us16",
              },
              {
                text: "us17 - PVC CSI",
                link: "/0.us/us17",
              },
              {
                text: "us206 - Mise en place d'une stack de Monitoring",
                link: "/0.us/us206",
              },
              {
                text: "us216 - Mise en place NetPolicy",
                link: "/0.us/us216",
              },
            ],
          },
        ],
      },
    ],

    socialLinks: [
      { icon: "github", link: "https://github.com/batleforc/weebo-si" },
      { icon: "twitch", link: "https://twitch.tv/batleforc" },
      { icon: "twitter", link: "https://twitter.com/maxweebo" },
      {
        icon: "bluesky",
        link: "https://bsky.app/profile/maxweebo.bsky.social",
      },
    ],
  },
});
