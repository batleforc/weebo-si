import type { BaseLayoutProps } from 'fumadocs-ui/layouts/shared';
import { Globe } from 'lucide-react';
import { gitConfig } from './shared';

function NavLogo() {
  return (
    <img
      src={`${import.meta.env.BASE_URL}logo-mark.png`}
      alt="Weebo SI"
      width={28}
      height={28}
    />
  );
}

export function baseOptions(): BaseLayoutProps {
  return {
    nav: {
      title: <NavLogo />,
    },
    githubUrl: `https://github.com/${gitConfig.user}/${gitConfig.repo}`,
    links: [
      {
        // Hors du perimetre de la SPA (site VitePress statique): lien brut,
        // construit sur BASE_URL pour rester juste en dev comme sur Pages.
        text: 'Archive v2',
        url: `${import.meta.env.BASE_URL}v2/`,
        external: true,
      },
      {
        type: 'icon',
        label: 'maxleriche.net',
        text: 'maxleriche.net',
        url: 'https://maxleriche.net',
        icon: <Globe />,
        external: true,
      },
    ],
  };
}
