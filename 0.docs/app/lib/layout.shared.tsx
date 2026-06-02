import type { BaseLayoutProps } from 'fumadocs-ui/layouts/shared';
import { Globe } from 'lucide-react';
import { gitConfig } from './shared';

function NavLogo() {
  return (
    <img
      src="/logo-mark.png"
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
