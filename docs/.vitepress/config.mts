import { defineConfig } from "vitepress";

import MermaidExample from "./mermaid-markdown-all.js";

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "Weebo-Env",
  description:
    "A Weebo Env made to test new cool stuff and in the make the next Gen WeeboGitOps env",
  base: "/weebo-si/",
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

    sidebar: [
      {
        text: "0. Introduction",
        items: [
          { text: "Introduction", link: "/0.introduction/home" },
          { text: "Sources", link: "/0.introduction/sources" },
          { text: "Contribuer", link: "/0.introduction/contributing" },
          { text: "Etape", link: "/0.introduction/etape" },
        ],
      },
      {
        text: "1. Création de l'infrastructure",
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
