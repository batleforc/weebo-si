// OKLCH -> sRGB, with chroma reduction for out-of-gamut values (The In-Gamut Rule).

const rad = (d) => (d * Math.PI) / 180;

export function parseOklch(str) {
  const m = /^oklch\(\s*([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*\)$/i.exec(String(str).trim());
  if (!m) throw new Error(`Not an oklch(L C H) colour: ${str}`);
  return [Number(m[1]), Number(m[2]), Number(m[3])];
}

const lchToLab = ([L, C, H]) => [L, C * Math.cos(rad(H)), C * Math.sin(rad(H))];
const labToLch = ([L, a, b]) => [L, Math.hypot(a, b), ((Math.atan2(b, a) * 180) / Math.PI + 360) % 360];

function labToLinear([L, a, b]) {
  const l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3;
  const m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3;
  const s = (L - 0.0894841775 * a - 1.291485548 * b) ** 3;
  return [
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s,
  ];
}

const inGamut = (rgb, eps = 1e-4) => rgb.every((v) => v >= -eps && v <= 1 + eps);

export function toLinear([L, C, H]) {
  L = Math.min(Math.max(L, 0), 1);
  const rgb = labToLinear(lchToLab([L, C, H]));
  if (inGamut(rgb)) return rgb;
  let lo = 0;
  let hi = C;
  for (let i = 0; i < 30; i++) {
    const mid = (lo + hi) / 2;
    if (inGamut(labToLinear(lchToLab([L, mid, H])))) lo = mid;
    else hi = mid;
  }
  return labToLinear(lchToLab([L, lo, H]));
}

const clamp01 = (v) => Math.min(Math.max(v, 0), 1);
const encode = (v) => {
  v = clamp01(v);
  return v <= 0.0031308 ? 12.92 * v : 1.055 * v ** (1 / 2.4) - 0.055;
};
const byte = (n) => Math.round(n).toString(16).padStart(2, "0");

/** sRGB hex, optionally with an alpha byte. */
export function hex(lch, alpha) {
  const out = "#" + toLinear(lch).map((v) => byte(encode(v) * 255)).join("");
  return alpha === undefined ? out : out + byte(alpha * 255);
}

/** Interpolate in OKLab; t = 0 gives a, t = 1 gives b. */
export function mix(a, b, t) {
  const la = lchToLab(a);
  const lb = lchToLab(b);
  return labToLch(la.map((x, i) => x + (lb[i] - x) * t));
}

function luminance(lch) {
  const [r, g, b] = toLinear(lch).map(clamp01);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/** WCAG 2 contrast ratio. */
export function contrast(a, b) {
  const [x, y] = [luminance(a), luminance(b)].sort((p, q) => q - p);
  return (x + 0.05) / (y + 0.05);
}
