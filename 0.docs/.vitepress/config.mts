import { defineConfig, HeadConfig } from "vitepress";
import { RSSOptions, RssPlugin } from "vitepress-plugin-rss";
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
const baseUrl = "https://batleforc.github.io";
const RSS: RSSOptions = {
  title: "Weebo-Env",
  baseUrl,
  copyright: `Copyright (c) 2025-present, Batleforc`,
  authors: [
    {
      name: "Batleforc",
      link: "https://github.com/batleforc",
    },
  ],
};

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
          { text: "Architecture", link: "/0.introduction/architecture" },
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
        items: [
          {
            text: "Mise en place CAPI",
            link: "/2.gestion/capi",
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
                text: "Stream - 15/03/2025",
                link: "/0.introduction/stream/15-03-2025",
              },
              {
                text: "Stream - 22/03/2025",
                link: "/0.introduction/stream/22-03-2025",
              },
              {
                text: "Stream - 29/03/2025",
                link: "/0.introduction/stream/29-03-2025",
              },
              {
                text: "Stream - 12/04/2025",
                link: "/0.introduction/stream/12-04-2025",
              },
              {
                text: "Stream - 19/04/2025",
                link: "/0.introduction/stream/19-04-2025",
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

  vite: {
    plugins: [RssPlugin(RSS)],
  },
});
