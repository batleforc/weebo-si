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
        // L'archive est hors du perimetre de la SPA (site VitePress statique).
        // `type: 'custom'` parce qu'un item standard passe par le Link de
        // fumadocs: soit le Link React Router, qui reprefixerait le basename,
        // soit un target="_blank" impose par `external`. Ici un <a> nu, meme
        // onglet, navigation complete. L'URL est construite sur BASE_URL pour
        // rester juste en dev comme sur Pages.
        type: 'custom',
        children: (
          <a
            href={`${import.meta.env.BASE_URL}v2/`}
            className="inline-flex items-center gap-1 p-2 text-fd-muted-foreground transition-colors hover:text-fd-accent-foreground"
          >
            Archive v2
          </a>
        ),
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
