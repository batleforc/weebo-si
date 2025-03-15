import { defineConfig, HeadConfig } from "vitepress";

import MermaidExample from "./mermaid-markdown-all.js";

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

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "Weebo-Env",
  description:
    "A Weebo Env made to test new cool stuff and in the make the next Gen WeeboGitOps env",
  base: "/weebo-si/",
  head: headers,
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

    sidebar: [
      {
        text: "0. Introduction",
        items: [
          { text: "Introduction", link: "/0.introduction/home" },
          { text: "Sources", link: "/0.introduction/sources" },
          { text: "Contribuer", link: "/0.introduction/contributing" },
          { text: "Etape", link: "/0.introduction/etape" },
          { text: "Kanban", link: "/0.introduction/kanban" },
        ],
      },
      {
        text: "1. Création de l'infrastructure",
        items: [
          {
            text: "Préparation du poste de travail",
            link: "/1.infrastructure/prepare-pc",
          },
          {
            text: "Préparation du serveur",
            link: "/1.infrastructure/prepare-server",
          },
          {
            text: "Préparation pour nos premières VM",
            link: "/1.infrastructure/prepare-first-vm",
          },
          {
            text: "Création de la première VM CAPI",
            link: "/1.infrastructure/creation-capi",
          },
        ],
      },
      {
        text: "2. Gestion de l'infrastructure",
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
      },
    ],

    socialLinks: [
      { icon: "github", link: "https://github.com/batleforc/weebo-si" },
    ],
  },
});
