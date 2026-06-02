import type { Route } from './+types/home';
import { HomeLayout } from 'fumadocs-ui/layouts/home';
import { Link } from 'react-router';
import { baseOptions } from '@/lib/layout.shared';

export function meta({}: Route.MetaArgs) {
  return [
    { title: 'Weebo SI — L\'env de dev presque parfait' },
    { name: 'description', content: 'Documentation de l\'environnement Kubernetes de dev et d\'expérimentation Weebo SI.' },
  ];
}

export default function Home() {
  return (
    <HomeLayout {...baseOptions()}>
      <main className="flex flex-col items-center justify-center flex-1 px-5 py-20 text-center relative overflow-hidden">
        {/* Radial crimson glow behind the hero */}
        <div
          className="absolute inset-0 pointer-events-none"
          style={{
            background: 'radial-gradient(ellipse 70% 60% at 50% 40%, oklch(0.65 0.26 25 / 0.10), transparent)',
          }}
        />

        {/* Eyebrow */}
        <p
          className="mb-6 text-xs font-semibold uppercase tracking-widest"
          style={{ color: 'oklch(0.72 0.14 52)', fontFamily: 'var(--font-mono)' }}
        >
          Saison 3 — Work in progress
        </p>

        {/* Hero name */}
        <h1
          className="mb-4 font-extrabold leading-tight tracking-tight cyber-text-glow"
          style={{
            fontFamily: 'var(--font-mono)',
            fontSize: 'clamp(2.5rem, 8vw, 4.5rem)',
            background: 'linear-gradient(135deg, oklch(0.93 0.018 25), oklch(0.65 0.26 25))',
            WebkitBackgroundClip: 'text',
            backgroundClip: 'text',
            color: 'transparent',
          }}
        >
          Weebo SI
        </h1>

        {/* Tagline */}
        <p
          className="mb-3 font-semibold"
          style={{
            fontFamily: 'var(--font-mono)',
            fontSize: '1.1rem',
            color: 'oklch(0.93 0.018 25)',
          }}
        >
          L&apos;env de dev presque parfait.
        </p>

        {/* Description */}
        <p
          className="mb-10 max-w-xl"
          style={{
            color: 'oklch(0.58 0.04 30)',
            fontSize: '1rem',
            lineHeight: '1.7',
          }}
        >
          Un environnement Kubernetes complet pour le dev et l&apos;expérimentation —
          testé, documenté, en constante évolution.
        </p>

        {/* CTAs */}
        <div className="flex flex-wrap gap-3 justify-center">
          <Link
            to="/docs"
            className="inline-flex items-center gap-2 px-5 py-2.5 font-semibold text-sm transition-all duration-150 hover:-translate-y-px"
            style={{
              fontFamily: 'var(--font-mono)',
              background: 'oklch(0.65 0.26 25)',
              color: 'oklch(0.97 0.01 0)',
              borderRadius: '2px',
              boxShadow: 'var(--cyber-glow)',
            }}
          >
            Ouvrir la doc
          </Link>
          <a
            href="https://github.com/batleforc/weebo-si"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 px-5 py-2.5 font-semibold text-sm transition-all duration-150"
            style={{
              fontFamily: 'var(--font-mono)',
              color: 'oklch(0.65 0.26 25)',
              border: '1px solid oklch(0.65 0.26 25 / 0.5)',
              borderRadius: '2px',
            }}
          >
            GitHub
          </a>
        </div>

        {/* Footer signature */}
        <p
          className="mt-16 text-xs"
          style={{ color: 'oklch(0.45 0.03 30)', fontFamily: 'var(--font-mono)' }}
        >
          Made with ❤️ and too much coffee ☕
        </p>
      </main>
    </HomeLayout>
  );
}
