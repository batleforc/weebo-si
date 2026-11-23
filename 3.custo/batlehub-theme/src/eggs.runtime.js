// BatleHub easter eggs, the part that runs in the browser. src/eggs.mjs builds one
// script per target (Forgejo, Argo CD, the error pages) by replacing __CFG__ with
// that target's config. Plain JS, no dependency, nothing fetched.
(() => {
  // Argo CD also walks the ConfigMap's timestamped copy of this file: run once.
  if (window.__bhEggs) return;
  window.__bhEggs = true;
  const CFG = __CFG__;
  const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const session = (k, v) => {
    try {
      if (v === undefined) return sessionStorage.getItem(k);
      sessionStorage.setItem(k, v);
    } catch {
      return null;
    }
  };
  const addCss = (text) => {
    const s = document.createElement("style");
    s.textContent = text;
    document.head.append(s);
  };
  const svg = (name, cls = "") => {
    const [w, h, d] = CFG.sprites[name];
    return `<svg class="${cls}" viewBox="0 0 ${w} ${h}" aria-hidden="true"><path fill="currentColor" d="${d}"/></svg>`;
  };
  addCss(CFG.css);

  // ── Seasons: a date range recolours the accent, and sends a parade once a session ──
  const now = new Date();
  const md = `${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
  const forced = new URLSearchParams(location.search).get("bh-season"); // to preview one
  const season = CFG.seasons.find((s) =>
    forced ? s.name === forced : s.from <= s.to ? md >= s.from && md <= s.to : md >= s.from || md <= s.to,
  );
  const parade = (kind) => {
    const box = document.createElement("div");
    box.className = `bh-parade bh-parade-${kind}`;
    box.setAttribute("aria-hidden", "true");
    for (let i = 0; i < { bats: 6, snow: 40, crab: 1 }[kind]; i++) {
      const p = document.createElement("i");
      p.style.cssText = `--x:${Math.random() * 100}vw;--y:${10 + Math.random() * 60}vh;--d:${(Math.random() * 5).toFixed(2)}s`;
      if (kind === "bats") p.innerHTML = svg("bat");
      if (kind === "crab") p.innerHTML = svg("crab");
      box.append(p);
    }
    document.body.append(box);
    setTimeout(() => box.remove(), 20000);
  };
  if (season) {
    document.documentElement.dataset.bhSeason = season.name;
    addCss(season.css);
    if (season.parade && !still && (forced || !session("bh-parade"))) {
      session("bh-parade", "1");
      setTimeout(() => parade(season.parade), 1500);
    }
  }

  // ── Idle: the crab bounces around the screen until anything moves ──────────────
  if (CFG.idle) {
    let last = Date.now();
    let saver = null;
    const wake = () => {
      last = Date.now();
      saver?.remove();
      saver = null;
    };
    for (const t of ["keydown", "pointermove", "pointerdown", "wheel", "touchstart", "scroll"])
      addEventListener(t, wake, { passive: true, capture: true });
    setInterval(() => {
      if (saver || document.hidden || Date.now() - last < CFG.idle * 60000) return;
      saver = document.createElement("div");
      saver.className = "bh-saver";
      saver.setAttribute("aria-hidden", "true");
      saver.innerHTML = `<div class="bh-saver-x"><div class="bh-saver-y">${svg("crab")}</div></div>`;
      document.body.append(saver);
    }, 15000);
  }

  // ── Key sequences: a dialog, or a game in the error page's stage ────────────────
  const modal = (egg) => {
    if (document.querySelector("dialog.bh-egg")) return;
    const d = document.createElement("dialog");
    d.className = "bh-egg";
    d.setAttribute("aria-labelledby", "bh-egg-title");
    const h = document.createElement("h2");
    h.id = "bh-egg-title";
    h.textContent = egg.title;
    d.append(h);
    if (egg.text) {
      const p = document.createElement("p");
      p.textContent = egg.text;
      d.append(p);
    }
    const close = () => d.close();
    let go;
    if (egg.href) {
      go = document.createElement("a");
      go.href = egg.href;
      go.rel = "noopener noreferrer";
      const x = document.createElement("button");
      x.type = "button";
      x.className = "bh-egg-x";
      x.setAttribute("aria-label", "Close");
      x.textContent = "×";
      x.addEventListener("click", close);
      d.append(x);
    } else {
      go = document.createElement("button");
      go.type = "button";
      go.addEventListener("click", close);
    }
    go.className = "bh-egg-go";
    go.textContent = egg.button;
    d.append(go);
    d.addEventListener("close", () => d.remove());
    document.body.append(d);
    d.showModal();
    go.focus();
  };

  // What every game shares: a canvas filling the stage, the theme's colours, a sprite
  // painter, the score line and the session's best score under `id`.
  const canvasGame = (stage, id, title, help) => {
    const c = document.createElement("canvas");
    c.className = "bh-game";
    c.tabIndex = 0;
    c.setAttribute("role", "img");
    c.setAttribute("aria-label", `${title}: ${help}`);
    stage.append(c);
    c.focus();
    const ctx = c.getContext("2d");
    const css = getComputedStyle(stage);
    const colour = (name, fallback) => css.getPropertyValue(`--bh-${name}`).trim() || fallback;
    const g = {
      c,
      ctx,
      ink: colour("ink", "#888"),
      dim: colour("ink-dim", "#777"),
      rule: colour("rule-soft", "#999"),
      accent: colour("accent", "#c33"),
      copper: colour("copper", "#b63"),
      w: 0,
      h: 0,
      best: Number(session(`bh-${id}-best`)) || 0,
      fit() {
        const r = stage.getBoundingClientRect();
        const dpr = devicePixelRatio || 1;
        [g.w, g.h] = [r.width, r.height];
        c.width = g.w * dpr;
        c.height = g.h * dpr;
        ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      },
      sprite(path, x, top, fill, u) {
        ctx.save();
        ctx.translate(Math.round(x), Math.round(top));
        ctx.scale(u, u);
        ctx.fillStyle = fill;
        ctx.fill(path);
        ctx.restore();
      },
      hud(score, state, start) {
        ctx.fillStyle = g.ink;
        ctx.font = `16px ${getComputedStyle(document.body).fontFamily}`;
        ctx.textAlign = "right";
        ctx.fillText(`${Math.floor(score)}  ·  best ${g.best}`, g.w - 24, 28);
        ctx.textAlign = "center";
        if (state === "ready") ctx.fillText(start, g.w / 2, g.h / 2);
        if (state === "over") ctx.fillText("GAME OVER · SPACE TO RETRY", g.w / 2, g.h / 2);
      },
      over(score) {
        g.best = Math.max(g.best, Math.floor(score));
        session(`bh-${id}-best`, String(g.best));
        c.setAttribute("aria-label", `${title}: game over, ${Math.floor(score)} points, best ${g.best}. Space to retry.`);
      },
    };
    return g;
  };

  // Crab run: jump over the bugs, stay low under the bats. Space, ArrowUp or a tap;
  // any of them restarts. Obstacles are drawn at random, harder ones unlocked by score.
  const crabRun = (stage) => {
    const g = canvasGame(stage, "run", "Crab run", "press Space or tap to jump over the bugs, stay down under the bats.");
    const crab = new Path2D(CFG.sprites.crab[2]);
    const art = { bug: new Path2D(CFG.sprites.bug[2]), bat: new Path2D(CFG.sprites.bat[2]) };
    const size = { bug: CFG.sprites.bug, bat: CFG.sprites.bat };
    const U = 4; // CSS px per sprite pixel, the stage's --u
    const G = 2400;
    const CRAB_X = 48;
    // [sprite, dx, dy] in sprite px, dy above the floor. "triple" needs speed 480 (score 80)
    // to be cleared in one jump; a bat at 14 only hits a jumping crab.
    const KINDS = [
      { from: 0, weight: 4, parts: [["bug", 0, 0]] },
      { from: 15, weight: 2, parts: [["bug", 0, 0], ["bug", 9, 0]] },
      { from: 30, weight: 2, parts: [["bug", 0, 0], ["bug", 0, 5]] },
      { from: 45, weight: 2, parts: [["bat", 0, 14]] },
      { from: 80, weight: 1, parts: [["bug", 0, 0], ["bug", 9, 0], ["bug", 18, 0]] },
    ];
    const pick = () => {
      const open = KINDS.filter((k) => score >= k.from);
      let r = Math.random() * open.reduce((s, k) => s + k.weight, 0);
      return open.find((k) => (r -= k.weight) < 0) ?? open[0];
    };
    // Each part as a box in px: x from the obstacle's left edge, h above the floor.
    const boxes = (o) =>
      o.kind.parts.map(([s, dx, dy]) => ({ s, x0: o.x + dx * U, x1: o.x + (dx + size[s][0]) * U, h0: dy * U, h1: (dy + size[s][1]) * U }));
    let state = "ready";
    let y = 0; // crab height above the floor
    let vy = 0;
    let obstacles = [];
    let next = 0;
    let score = 0;
    let then = 0;
    const draw = () => {
      g.ctx.clearRect(0, 0, g.w, g.h);
      g.sprite(crab, CRAB_X, g.h - 13 * U - y, g.accent, U);
      for (const o of obstacles) for (const b of boxes(o)) g.sprite(art[b.s], b.x0, g.h - b.h1, b.s === "bat" ? g.copper : g.ink, U);
      g.hud(score, state, "PRESS SPACE TO RUN");
    };
    const tick = (t) => {
      const dt = Math.min((t - then) / 1000, 0.05);
      then = t;
      const speed = 320 + score * 2;
      score += dt * 10;
      vy -= G * dt;
      y = Math.max(0, y + vy * dt);
      if (y === 0) vy = 0;
      for (const o of obstacles) o.x -= speed * dt;
      obstacles = obstacles.filter((o) => o.x > -30 * U);
      if ((next -= dt) <= 0) {
        const kind = pick();
        const width = Math.max(...kind.parts.map(([s, dx]) => (dx + size[s][0]) * U));
        obstacles.push({ x: g.w, kind });
        next = width / speed + 0.75 + Math.random() * 1.2; // the crab always lands in between
      }
      // The body only (columns 6-20, rows 6-12): a claw grazing a bug is fair.
      const hit = (b) => b.x0 < CRAB_X + 20 * U && b.x1 > CRAB_X + 6 * U && b.h0 < y + 7 * U && b.h1 > y;
      if (obstacles.some((o) => boxes(o).some(hit))) {
        state = "over";
        g.over(score);
      }
      draw();
      if (state === "run") requestAnimationFrame(tick);
    };
    const jump = (ev) => {
      if (ev.type === "keydown" && ev.key !== " " && ev.key !== "ArrowUp") return;
      ev.preventDefault();
      if (state !== "run") {
        [state, y, vy, obstacles, next, score] = ["run", 0, 0, [], 0.6, 0];
        then = performance.now();
        requestAnimationFrame(tick);
      } else if (y === 0) vy = 650; // apex ~88px: the crab stays inside the 144px stage
    };
    addEventListener("keydown", jump);
    g.c.addEventListener("pointerdown", jump);
    addEventListener("resize", () => (g.fit(), draw()));
    g.fit();
    draw();
  };

  // Shelf climb: the crab bounces up a library from book to book. It bounces by
  // itself; ArrowLeft / ArrowRight (or holding a side of the stage) steer, and the sides
  // wrap. Some books slide; a falling one breaks. Missing every book below ends the run.
  const shelfClimb = (stage) => {
    stage.style.height = "min(520px, 75vh)"; // a climb needs height: the stage grows
    const g = canvasGame(stage, "climb", "Shelf climb", "press Space or tap to start, ArrowLeft and ArrowRight to steer.");
    const crab = new Path2D(CFG.sprites.crab[2]);
    const U = 2; // 52 px wide: still fits on a 60 px book
    const RW = CFG.sprites.crab[0] * U;
    const RH = CFG.sprites.crab[1] * U;
    const [G, BOUNCE, STEER] = [1800, 760, 340]; // apex ~160px: every gap below is reachable
    const BOOK = { w: 60, h: 12 };
    const COVERS = [g.accent, g.copper, g.dim, g.ink];
    const SHELF = 120; // px between two planks of the bookcase behind
    let state = "ready";
    let x = 0;
    let y = 0; // crab's feet, world px above the start
    let vy = 0;
    let cam = 0; // world y at the bottom of the stage
    let top = 0; // highest book made so far
    let books = [];
    let steer = 0;
    let then = 0;
    // The bookcase: a centred column, narrow enough that every book is in reach.
    const W = () => Math.min(g.w, 420);
    const ox = () => (g.w - W()) / 2;
    const book = (by) => {
      const climbed = by / 10;
      const kind = Math.random() < Math.min(0.3, climbed / 2000) ? "slide" : Math.random() < Math.min(0.2, climbed / 3000) ? "loose" : "fixed";
      return { x: Math.random() * (W() - BOOK.w), y: by, kind, vx: kind === "slide" ? 90 : 0, fall: 0, cover: COVERS[Math.floor(Math.random() * COVERS.length)] };
    };
    const stock = () => {
      while (top < cam + g.h + 60) {
        top += 50 + Math.random() * Math.min(90, 30 + top / 40); // wider gaps higher up
        books.push(book(top));
      }
    };
    const screenY = (wy) => g.h - (wy - cam);
    const draw = () => {
      const { ctx } = g;
      ctx.clearRect(0, 0, g.w, g.h);
      ctx.fillStyle = g.rule;
      ctx.fillRect(ox() - 4, 0, 4, g.h);
      ctx.fillRect(ox() + W(), 0, 4, g.h);
      for (let p = Math.ceil(cam / SHELF) * SHELF; p < cam + g.h; p += SHELF) ctx.fillRect(ox(), screenY(p), W(), 2);
      ctx.save();
      ctx.beginPath();
      ctx.rect(ox(), 0, W(), g.h);
      ctx.clip(); // the crab wrapping round shows on both sides of the case, not past them
      ctx.translate(ox(), 0);
      for (const b of books) {
        const sy = screenY(b.y);
        ctx.fillStyle = b.cover;
        ctx.fillRect(Math.round(b.x), sy, BOOK.w, BOOK.h);
        ctx.fillStyle = g.rule; // the spine's bands; a loose book shows its pages
        ctx.fillRect(Math.round(b.x) + 6, sy, 3, BOOK.h);
        ctx.fillRect(Math.round(b.x) + BOOK.w - 9, sy, 3, BOOK.h);
        if (b.kind === "loose") ctx.fillRect(Math.round(b.x) + 12, sy + BOOK.h - 3, BOOK.w - 24, 2);
      }
      for (const dx of [0, -W(), W()]) g.sprite(crab, x + dx, screenY(y) - RH, g.accent, U);
      ctx.restore();
      g.hud(cam / 10, state, "PRESS SPACE TO CLIMB");
    };
    const tick = (t) => {
      const dt = Math.min((t - then) / 1000, 0.05);
      then = t;
      x = (((x + steer * STEER * dt) % W()) + W()) % W();
      const was = y;
      vy -= G * dt;
      y += vy * dt;
      for (const b of books) {
        if (b.kind === "slide") {
          b.x += b.vx * dt;
          if (b.x < 0 || b.x > W() - BOOK.w) b.vx = -b.vx;
        }
        if (b.fall) b.y -= (b.fall += G * dt) * dt;
      }
      // Feet crossing a book's top on the way down; the crab wraps, so test both sides.
      const landed = vy < 0 && books.find((b) => !b.fall && was >= b.y && y <= b.y &&
        [x, x - W(), x + W()].some((rx) => rx + RW - 6 > b.x && rx + 6 < b.x + BOOK.w));
      if (landed) {
        if (landed.kind === "loose") landed.fall = 1;
        else [y, vy] = [landed.y, BOUNCE];
      }
      cam = Math.max(cam, y - g.h * 0.45);
      books = books.filter((b) => b.y > cam - 40);
      stock();
      if (y < cam - RH) {
        state = "over";
        g.over(cam / 10);
      }
      draw();
      if (state === "run") requestAnimationFrame(tick);
    };
    const start = () => {
      [state, y, vy, cam, top, steer] = ["run", 0, BOUNCE, 0, 0, 0];
      x = (W() - RW) / 2;
      books = [{ x: (W() - BOOK.w) / 2, y: 0, kind: "fixed", vx: 0, fall: 0, cover: g.accent }];
      stock();
      then = performance.now();
      requestAnimationFrame(tick);
    };
    const KEYS = { ArrowLeft: -1, ArrowRight: 1 };
    addEventListener("keydown", (ev) => {
      if (!(ev.key in KEYS) && ev.key !== " ") return;
      ev.preventDefault();
      if (ev.key in KEYS) steer = KEYS[ev.key];
      else if (state !== "run") start();
    });
    addEventListener("keyup", (ev) => {
      if (KEYS[ev.key] === steer) steer = 0;
    });
    g.c.addEventListener("pointerdown", (ev) => {
      if (state !== "run") return start();
      steer = ev.offsetX < g.w / 2 ? -1 : 1;
    });
    for (const t of ["pointerup", "pointercancel", "pointerleave"]) g.c.addEventListener(t, () => (steer = 0));
    addEventListener("resize", () => (g.fit(), draw()));
    g.fit();
    draw();
  };

  const GAMES = { "crab-run": crabRun, "shelf-climb": shelfClimb };
  const play = (name) => {
    const stage = document.querySelector(".bh-stage");
    if (!stage || stage.dataset.playing) return;
    stage.dataset.playing = name;
    stage.removeAttribute("aria-hidden");
    stage.replaceChildren();
    GAMES[name](stage);
  };

  if (CFG.eggs.length) {
    const max = Math.max(...CFG.eggs.map((e) => e.seq.length));
    const typed = [];
    const editable = (el) =>
      el instanceof Element && el.closest("input, textarea, select, [contenteditable=''], [contenteditable='true']");
    addEventListener("keydown", (ev) => {
      if (ev.ctrlKey || ev.metaKey || ev.altKey || editable(ev.target)) return;
      typed.push(ev.key.length === 1 ? ev.key.toLowerCase() : ev.key);
      if (typed.length > max) typed.shift();
      // Leading separator: "ArrowUp" must not end in a typed "p".
      const tail = "\n" + typed.join("\n");
      const egg = CFG.eggs.find((e) => tail.endsWith("\n" + e.seq.join("\n")));
      if (!egg) return;
      typed.length = 0;
      if (egg.game) play(egg.game);
      else modal(egg);
    });
  }
})();
