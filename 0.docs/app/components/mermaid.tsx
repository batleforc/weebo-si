'use client';

import { use, useCallback, useEffect, useId, useRef, useState } from 'react';
import { useTheme } from 'next-themes';
import { Maximize2, X, ZoomIn, ZoomOut } from 'lucide-react';

export function Mermaid({ chart }: { chart: string }) {
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted) return;
  return <MermaidContent chart={chart} />;
}

const cache = new Map<string, Promise<unknown>>();

function cachePromise<T>(key: string, setPromise: () => Promise<T>): Promise<T> {
  const cached = cache.get(key);
  if (cached) return cached as Promise<T>;

  const promise = setPromise();
  cache.set(key, promise);
  return promise;
}

/**
 * The width mermaid laid the diagram out at, which it writes as an inline
 * `max-width` on the svg. That width is where the labels are at their real
 * font size, so it is the floor we never render below.
 */
function naturalWidth(svg: string): number | undefined {
  const match = /max-width:\s*([\d.]+)px/.exec(svg);

  return match ? Number(match[1]) : undefined;
}

function MermaidContent({ chart }: { chart: string }) {
  const id = useId();
  const { resolvedTheme } = useTheme();
  const { default: mermaid } = use(cachePromise('mermaid', () => import('mermaid')));
  const [zoomed, setZoomed] = useState(false);

  mermaid.initialize({
    startOnLoad: false,
    securityLevel: 'loose',
    fontFamily: 'inherit',
    themeCSS: 'margin: 1.5rem auto 0;',
    theme: resolvedTheme === 'dark' ? 'dark' : 'default',
  });

  const { svg, bindFunctions } = use(
    cachePromise(`${chart}-${resolvedTheme}`, () => {
      return mermaid.render(id, chart.replaceAll('\\n', '\n'));
    }),
  );

  const width = naturalWidth(svg);

  return (
    <div className="relative my-6">
      <div className="mermaid-diagram overflow-x-auto">
        <div
          style={{ minWidth: width ? `${width}px` : undefined }}
          ref={(container) => {
            if (container) bindFunctions?.(container);
          }}
          dangerouslySetInnerHTML={{ __html: svg }}
        />
      </div>
      <button
        type="button"
        onClick={() => setZoomed(true)}
        aria-label="Agrandir le schéma"
        className="absolute top-2 right-2 rounded-md border border-fd-border bg-fd-card/80 p-1.5 text-fd-muted-foreground opacity-0 backdrop-blur transition-opacity hover:text-fd-foreground focus-visible:opacity-100 md:opacity-60 md:hover:opacity-100"
      >
        <Maximize2 className="size-4" />
      </button>
      {zoomed ? <MermaidZoom svg={svg} width={width} onClose={() => setZoomed(false)} /> : null}
    </div>
  );
}

const ZOOM_STEP = 0.25;
const ZOOM_RANGE = [0.5, 4] as const;

function MermaidZoom({
  svg,
  width,
  onClose,
}: {
  svg: string;
  width: number | undefined;
  onClose: () => void;
}) {
  const [scale, setScale] = useState(1);
  const closeRef = useRef<HTMLButtonElement>(null);

  const zoom = useCallback((by: number) => {
    setScale((current) => Math.min(ZOOM_RANGE[1], Math.max(ZOOM_RANGE[0], current + by)));
  }, []);

  useEffect(() => {
    closeRef.current?.focus();

    function onKeyDown(event: KeyboardEvent) {
      if (event.key === 'Escape') onClose();
      if (event.key === '+' || event.key === '=') zoom(ZOOM_STEP);
      if (event.key === '-') zoom(-ZOOM_STEP);
    }

    document.addEventListener('keydown', onKeyDown);
    return () => document.removeEventListener('keydown', onKeyDown);
  }, [onClose, zoom]);

  return (
    <div
      className="fixed inset-0 z-50 flex flex-col bg-fd-background/95 backdrop-blur"
      // The backdrop closes, the diagram itself does not -- panning a zoomed
      // diagram means dragging inside it.
      onClick={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <div className="flex items-center justify-end gap-1 border-b border-fd-border p-2">
        <button
          type="button"
          onClick={() => zoom(-ZOOM_STEP)}
          aria-label="Dézoomer"
          className="rounded-md p-1.5 text-fd-muted-foreground hover:bg-fd-accent hover:text-fd-foreground"
        >
          <ZoomOut className="size-4" />
        </button>
        <span className="w-12 text-center text-xs text-fd-muted-foreground tabular-nums">
          {Math.round(scale * 100)}%
        </span>
        <button
          type="button"
          onClick={() => zoom(ZOOM_STEP)}
          aria-label="Zoomer"
          className="rounded-md p-1.5 text-fd-muted-foreground hover:bg-fd-accent hover:text-fd-foreground"
        >
          <ZoomIn className="size-4" />
        </button>
        <button
          ref={closeRef}
          type="button"
          onClick={onClose}
          aria-label="Fermer"
          className="rounded-md p-1.5 text-fd-muted-foreground hover:bg-fd-accent hover:text-fd-foreground"
        >
          <X className="size-4" />
        </button>
      </div>
      <div className="mermaid-zoom flex-1 overflow-auto p-4">
        <div
          style={{ width: width ? `${width * scale}px` : undefined }}
          dangerouslySetInnerHTML={{ __html: svg }}
        />
      </div>
    </div>
  );
}
