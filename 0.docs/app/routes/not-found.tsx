import type { Route } from './+types/not-found';
import { HomeLayout } from 'fumadocs-ui/layouts/home';
import { Link } from 'react-router';
import { baseOptions } from '@/lib/layout.shared';

export function meta({}: Route.MetaArgs) {
  return [{ title: '404 — Page introuvable' }];
}

export default function NotFound() {
  return (
    <HomeLayout {...baseOptions()}>
      <main className="flex flex-col items-center justify-center flex-1 px-5 py-20 text-center">
        <p
          className="mb-3 text-xs font-semibold uppercase tracking-widest"
          style={{ color: 'oklch(0.72 0.14 52)', fontFamily: 'var(--font-mono)' }}
        >
          Erreur 404
        </p>
        <h1
          className="mb-4 font-bold cyber-text-glow"
          style={{
            fontFamily: 'var(--font-mono)',
            fontSize: 'clamp(2rem, 6vw, 3.5rem)',
            color: 'oklch(0.65 0.26 25)',
          }}
        >
          Page introuvable.
        </h1>
        <p
          className="mb-8 max-w-sm"
          style={{ color: 'oklch(0.58 0.04 30)', lineHeight: '1.7' }}
        >
          Cette page n&apos;existe pas dans notre cluster. Vérifiez l&apos;URL ou revenez à la doc.
        </p>
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
          Retour à la doc
        </Link>
      </main>
    </HomeLayout>
  );
}
