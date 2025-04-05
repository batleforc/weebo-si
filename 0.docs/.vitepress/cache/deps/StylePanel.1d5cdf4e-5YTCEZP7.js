import {
  A,
  DL,
  F,
  I,
  I3,
  J,
  J3,
  KC,
  L3,
  M2,
  Mf,
  N4,
  QN,
  S2,
  Sf,
  U0,
  U2,
  W8,
  YN,
  Yl,
  Z3,
  _2,
  b,
  cL,
  lr,
  n5,
  p1,
  p3,
  q2,
  q6,
  qL,
  rr,
  s1,
  u3,
  w3,
  wC,
  x1,
  xC,
  y2
} from "./chunk-3BWTDND5.js";
import "./chunk-FDBJFBLO.js";

// node_modules/@zenuml/core/dist/StylePanel.1d5cdf4e.js
var Ve = ["top", "right", "bottom", "left"];
var Le = ["start", "end"];
var Fe = Ve.reduce((e, t) => e.concat(t, t + "-" + Le[0], t + "-" + Le[1]), []);
var Z = Math.min;
var q = Math.max;
var ae = Math.round;
var le = Math.floor;
var Y = (e) => ({
  x: e,
  y: e
});
var Bt = {
  left: "right",
  right: "left",
  bottom: "top",
  top: "bottom"
};
var Dt = {
  start: "end",
  end: "start"
};
function ye(e, t, n) {
  return q(e, Z(t, n));
}
function K(e, t) {
  return typeof e == "function" ? e(t) : e;
}
function V(e) {
  return e.split("-")[0];
}
function W(e) {
  return e.split("-")[1];
}
function Ue(e) {
  return e === "x" ? "y" : "x";
}
function be(e) {
  return e === "y" ? "height" : "width";
}
function de(e) {
  return ["top", "bottom"].includes(V(e)) ? "y" : "x";
}
function Ce(e) {
  return Ue(de(e));
}
function Ye(e, t, n) {
  n === void 0 && (n = false);
  const i = W(e), o = Ce(e), r = be(o);
  let s = o === "x" ? i === (n ? "end" : "start") ? "right" : "left" : i === "start" ? "bottom" : "top";
  return t.reference[r] > t.floating[r] && (s = fe(s)), [s, fe(s)];
}
function Nt(e) {
  const t = fe(e);
  return [ce(e), t, ce(t)];
}
function ce(e) {
  return e.replace(/start|end/g, (t) => Dt[t]);
}
function $t(e, t, n) {
  const i = ["left", "right"], o = ["right", "left"], r = ["top", "bottom"], s = ["bottom", "top"];
  switch (e) {
    case "top":
    case "bottom":
      return n ? t ? o : i : t ? i : o;
    case "left":
    case "right":
      return t ? r : s;
    default:
      return [];
  }
}
function kt(e, t, n, i) {
  const o = W(e);
  let r = $t(V(e), n === "start", i);
  return o && (r = r.map((s) => s + "-" + o), t && (r = r.concat(r.map(ce)))), r;
}
function fe(e) {
  return e.replace(/left|right|bottom|top/g, (t) => Bt[t]);
}
function Mt(e) {
  return {
    top: 0,
    right: 0,
    bottom: 0,
    left: 0,
    ...e
  };
}
function Xe(e) {
  return typeof e != "number" ? Mt(e) : {
    top: e,
    right: e,
    bottom: e,
    left: e
  };
}
function ue(e) {
  const {
    x: t,
    y: n,
    width: i,
    height: o
  } = e;
  return {
    width: i,
    height: o,
    top: n,
    left: t,
    right: t + i,
    bottom: n + o,
    x: t,
    y: n
  };
}
function Be(e, t, n) {
  let {
    reference: i,
    floating: o
  } = e;
  const r = de(t), s = Ce(t), l = be(s), f = V(t), c = r === "y", u = i.x + i.width / 2 - o.width / 2, d = i.y + i.height / 2 - o.height / 2, g = i[l] / 2 - o[l] / 2;
  let m;
  switch (f) {
    case "top":
      m = {
        x: u,
        y: i.y - o.height
      };
      break;
    case "bottom":
      m = {
        x: u,
        y: i.y + i.height
      };
      break;
    case "right":
      m = {
        x: i.x + i.width,
        y: d
      };
      break;
    case "left":
      m = {
        x: i.x - o.width,
        y: d
      };
      break;
    default:
      m = {
        x: i.x,
        y: i.y
      };
  }
  switch (W(t)) {
    case "start":
      m[s] -= g * (n && c ? -1 : 1);
      break;
    case "end":
      m[s] += g * (n && c ? -1 : 1);
      break;
  }
  return m;
}
var jt = async (e, t, n) => {
  const {
    placement: i = "bottom",
    strategy: o = "absolute",
    middleware: r = [],
    platform: s
  } = n, l = r.filter(Boolean), f = await (s.isRTL == null ? void 0 : s.isRTL(t));
  let c = await s.getElementRects({
    reference: e,
    floating: t,
    strategy: o
  }), {
    x: u,
    y: d
  } = Be(c, i, f), g = i, m = {}, a = 0;
  for (let h = 0; h < l.length; h++) {
    const {
      name: v,
      fn: w
    } = l[h], {
      x: y,
      y: b2,
      data: C,
      reset: A2
    } = await w({
      x: u,
      y: d,
      initialPlacement: i,
      placement: g,
      strategy: o,
      middlewareData: m,
      rects: c,
      platform: s,
      elements: {
        reference: e,
        floating: t
      }
    });
    u = y != null ? y : u, d = b2 != null ? b2 : d, m = {
      ...m,
      [v]: {
        ...m[v],
        ...C
      }
    }, A2 && a <= 50 && (a++, typeof A2 == "object" && (A2.placement && (g = A2.placement), A2.rects && (c = A2.rects === true ? await s.getElementRects({
      reference: e,
      floating: t,
      strategy: o
    }) : A2.rects), {
      x: u,
      y: d
    } = Be(c, g, f)), h = -1);
  }
  return {
    x: u,
    y: d,
    placement: g,
    strategy: o,
    middlewareData: m
  };
};
async function oe(e, t) {
  var n;
  t === void 0 && (t = {});
  const {
    x: i,
    y: o,
    platform: r,
    rects: s,
    elements: l,
    strategy: f
  } = e, {
    boundary: c = "clippingAncestors",
    rootBoundary: u = "viewport",
    elementContext: d = "floating",
    altBoundary: g = false,
    padding: m = 0
  } = K(t, e), a = Xe(m), v = l[g ? d === "floating" ? "reference" : "floating" : d], w = ue(await r.getClippingRect({
    element: (n = await (r.isElement == null ? void 0 : r.isElement(v))) == null || n ? v : v.contextElement || await (r.getDocumentElement == null ? void 0 : r.getDocumentElement(l.floating)),
    boundary: c,
    rootBoundary: u,
    strategy: f
  })), y = d === "floating" ? {
    x: i,
    y: o,
    width: s.floating.width,
    height: s.floating.height
  } : s.reference, b2 = await (r.getOffsetParent == null ? void 0 : r.getOffsetParent(l.floating)), C = await (r.isElement == null ? void 0 : r.isElement(b2)) ? await (r.getScale == null ? void 0 : r.getScale(b2)) || {
    x: 1,
    y: 1
  } : {
    x: 1,
    y: 1
  }, A2 = ue(r.convertOffsetParentRelativeRectToViewportRelativeRect ? await r.convertOffsetParentRelativeRectToViewportRelativeRect({
    elements: l,
    rect: y,
    offsetParent: b2,
    strategy: f
  }) : y);
  return {
    top: (w.top - A2.top + a.top) / C.y,
    bottom: (A2.bottom - w.bottom + a.bottom) / C.y,
    left: (w.left - A2.left + a.left) / C.x,
    right: (A2.right - w.right + a.right) / C.x
  };
}
var Ht = (e) => ({
  name: "arrow",
  options: e,
  async fn(t) {
    const {
      x: n,
      y: i,
      placement: o,
      rects: r,
      platform: s,
      elements: l,
      middlewareData: f
    } = t, {
      element: c,
      padding: u = 0
    } = K(e, t) || {};
    if (c == null)
      return {};
    const d = Xe(u), g = {
      x: n,
      y: i
    }, m = Ce(o), a = be(m), h = await s.getDimensions(c), v = m === "y", w = v ? "top" : "left", y = v ? "bottom" : "right", b2 = v ? "clientHeight" : "clientWidth", C = r.reference[a] + r.reference[m] - g[m] - r.floating[a], A2 = g[m] - r.reference[m], O = await (s.getOffsetParent == null ? void 0 : s.getOffsetParent(c));
    let p = O ? O[b2] : 0;
    (!p || !await (s.isElement == null ? void 0 : s.isElement(O))) && (p = l.floating[b2] || r.floating[a]);
    const T = C / 2 - A2 / 2, L = p / 2 - h[a] / 2 - 1, S = Z(d[w], L), B = Z(d[y], L), R = S, D = p - h[a] - B, F2 = p / 2 - h[a] / 2 + T, $ = ye(R, F2, D), j = !f.arrow && W(o) != null && F2 !== $ && r.reference[a] / 2 - (F2 < R ? S : B) - h[a] / 2 < 0, I2 = j ? F2 < R ? F2 - R : F2 - D : 0;
    return {
      [m]: g[m] + I2,
      data: {
        [m]: $,
        centerOffset: F2 - $ - I2,
        ...j && {
          alignmentOffset: I2
        }
      },
      reset: j
    };
  }
});
function Wt(e, t, n) {
  return (e ? [...n.filter((o) => W(o) === e), ...n.filter((o) => W(o) !== e)] : n.filter((o) => V(o) === o)).filter((o) => e ? W(o) === e || (t ? ce(o) !== o : false) : true);
}
var _t = function(e) {
  return e === void 0 && (e = {}), {
    name: "autoPlacement",
    options: e,
    async fn(t) {
      var n, i, o;
      const {
        rects: r,
        middlewareData: s,
        placement: l,
        platform: f,
        elements: c
      } = t, {
        crossAxis: u = false,
        alignment: d,
        allowedPlacements: g = Fe,
        autoAlignment: m = true,
        ...a
      } = K(e, t), h = d !== void 0 || g === Fe ? Wt(d || null, m, g) : g, v = await oe(t, a), w = ((n = s.autoPlacement) == null ? void 0 : n.index) || 0, y = h[w];
      if (y == null)
        return {};
      const b2 = Ye(y, r, await (f.isRTL == null ? void 0 : f.isRTL(c.floating)));
      if (l !== y)
        return {
          reset: {
            placement: h[0]
          }
        };
      const C = [v[V(y)], v[b2[0]], v[b2[1]]], A2 = [...((i = s.autoPlacement) == null ? void 0 : i.overflows) || [], {
        placement: y,
        overflows: C
      }], O = h[w + 1];
      if (O)
        return {
          data: {
            index: w + 1,
            overflows: A2
          },
          reset: {
            placement: O
          }
        };
      const p = A2.map((S) => {
        const B = W(S.placement);
        return [S.placement, B && u ? S.overflows.slice(0, 2).reduce((R, D) => R + D, 0) : S.overflows[0], S.overflows];
      }).sort((S, B) => S[1] - B[1]), L = ((o = p.filter((S) => S[2].slice(
        0,
        W(S[0]) ? 2 : 3
      ).every((B) => B <= 0))[0]) == null ? void 0 : o[0]) || p[0][0];
      return L !== l ? {
        data: {
          index: w + 1,
          overflows: A2
        },
        reset: {
          placement: L
        }
      } : {};
    }
  };
};
var zt = function(e) {
  return e === void 0 && (e = {}), {
    name: "flip",
    options: e,
    async fn(t) {
      var n, i;
      const {
        placement: o,
        middlewareData: r,
        rects: s,
        initialPlacement: l,
        platform: f,
        elements: c
      } = t, {
        mainAxis: u = true,
        crossAxis: d = true,
        fallbackPlacements: g,
        fallbackStrategy: m = "bestFit",
        fallbackAxisSideDirection: a = "none",
        flipAlignment: h = true,
        ...v
      } = K(e, t);
      if ((n = r.arrow) != null && n.alignmentOffset)
        return {};
      const w = V(o), y = V(l) === l, b2 = await (f.isRTL == null ? void 0 : f.isRTL(c.floating)), C = g || (y || !h ? [fe(l)] : Nt(l));
      !g && a !== "none" && C.push(...kt(l, h, a, b2));
      const A2 = [l, ...C], O = await oe(t, v), p = [];
      let T = ((i = r.flip) == null ? void 0 : i.overflows) || [];
      if (u && p.push(O[w]), d) {
        const R = Ye(o, s, b2);
        p.push(O[R[0]], O[R[1]]);
      }
      if (T = [...T, {
        placement: o,
        overflows: p
      }], !p.every((R) => R <= 0)) {
        var L, S;
        const R = (((L = r.flip) == null ? void 0 : L.index) || 0) + 1, D = A2[R];
        if (D)
          return {
            data: {
              index: R,
              overflows: T
            },
            reset: {
              placement: D
            }
          };
        let F2 = (S = T.filter(($) => $.overflows[0] <= 0).sort(($, j) => $.overflows[1] - j.overflows[1])[0]) == null ? void 0 : S.placement;
        if (!F2)
          switch (m) {
            case "bestFit": {
              var B;
              const $ = (B = T.map((j) => [j.placement, j.overflows.filter((I2) => I2 > 0).reduce((I2, st) => I2 + st, 0)]).sort((j, I2) => j[1] - I2[1])[0]) == null ? void 0 : B[0];
              $ && (F2 = $);
              break;
            }
            case "initialPlacement":
              F2 = l;
              break;
          }
        if (o !== F2)
          return {
            reset: {
              placement: F2
            }
          };
      }
      return {};
    }
  };
};
function De(e, t) {
  return {
    top: e.top - t.height,
    right: e.right - t.width,
    bottom: e.bottom - t.height,
    left: e.left - t.width
  };
}
function Ne(e) {
  return Ve.some((t) => e[t] >= 0);
}
var It = function(e) {
  return e === void 0 && (e = {}), {
    name: "hide",
    options: e,
    async fn(t) {
      const {
        rects: n
      } = t, {
        strategy: i = "referenceHidden",
        ...o
      } = K(e, t);
      switch (i) {
        case "referenceHidden": {
          const r = await oe(t, {
            ...o,
            elementContext: "reference"
          }), s = De(r, n.reference);
          return {
            data: {
              referenceHiddenOffsets: s,
              referenceHidden: Ne(s)
            }
          };
        }
        case "escaped": {
          const r = await oe(t, {
            ...o,
            altBoundary: true
          }), s = De(r, n.floating);
          return {
            data: {
              escapedOffsets: s,
              escaped: Ne(s)
            }
          };
        }
        default:
          return {};
      }
    }
  };
};
async function Vt(e, t) {
  const {
    placement: n,
    platform: i,
    elements: o
  } = e, r = await (i.isRTL == null ? void 0 : i.isRTL(o.floating)), s = V(n), l = W(n), f = de(n) === "y", c = ["left", "top"].includes(s) ? -1 : 1, u = r && f ? -1 : 1, d = K(t, e);
  let {
    mainAxis: g,
    crossAxis: m,
    alignmentAxis: a
  } = typeof d == "number" ? {
    mainAxis: d,
    crossAxis: 0,
    alignmentAxis: null
  } : {
    mainAxis: 0,
    crossAxis: 0,
    alignmentAxis: null,
    ...d
  };
  return l && typeof a == "number" && (m = l === "end" ? a * -1 : a), f ? {
    x: m * u,
    y: g * c
  } : {
    x: g * c,
    y: m * u
  };
}
var Ut = function(e) {
  return e === void 0 && (e = 0), {
    name: "offset",
    options: e,
    async fn(t) {
      var n, i;
      const {
        x: o,
        y: r,
        placement: s,
        middlewareData: l
      } = t, f = await Vt(t, e);
      return s === ((n = l.offset) == null ? void 0 : n.placement) && (i = l.arrow) != null && i.alignmentOffset ? {} : {
        x: o + f.x,
        y: r + f.y,
        data: {
          ...f,
          placement: s
        }
      };
    }
  };
};
var Yt = function(e) {
  return e === void 0 && (e = {}), {
    name: "shift",
    options: e,
    async fn(t) {
      const {
        x: n,
        y: i,
        placement: o
      } = t, {
        mainAxis: r = true,
        crossAxis: s = false,
        limiter: l = {
          fn: (v) => {
            let {
              x: w,
              y
            } = v;
            return {
              x: w,
              y
            };
          }
        },
        ...f
      } = K(e, t), c = {
        x: n,
        y: i
      }, u = await oe(t, f), d = de(V(o)), g = Ue(d);
      let m = c[g], a = c[d];
      if (r) {
        const v = g === "y" ? "top" : "left", w = g === "y" ? "bottom" : "right", y = m + u[v], b2 = m - u[w];
        m = ye(y, m, b2);
      }
      if (s) {
        const v = d === "y" ? "top" : "left", w = d === "y" ? "bottom" : "right", y = a + u[v], b2 = a - u[w];
        a = ye(y, a, b2);
      }
      const h = l.fn({
        ...t,
        [g]: m,
        [d]: a
      });
      return {
        ...h,
        data: {
          x: h.x - n,
          y: h.y - i
        }
      };
    }
  };
};
function te(e) {
  return qe(e) ? (e.nodeName || "").toLowerCase() : "#document";
}
function N(e) {
  var t;
  return (e == null || (t = e.ownerDocument) == null ? void 0 : t.defaultView) || window;
}
function U(e) {
  var t;
  return (t = (qe(e) ? e.ownerDocument : e.document) || window.document) == null ? void 0 : t.documentElement;
}
function qe(e) {
  return e instanceof Node || e instanceof N(e).Node;
}
function _(e) {
  return e instanceof Element || e instanceof N(e).Element;
}
function z(e) {
  return e instanceof HTMLElement || e instanceof N(e).HTMLElement;
}
function $e(e) {
  return typeof ShadowRoot > "u" ? false : e instanceof ShadowRoot || e instanceof N(e).ShadowRoot;
}
function se(e) {
  const {
    overflow: t,
    overflowX: n,
    overflowY: i,
    display: o
  } = M(e);
  return /auto|scroll|overlay|hidden|clip/.test(t + i + n) && !["inline", "contents"].includes(o);
}
function Xt(e) {
  return ["table", "td", "th"].includes(te(e));
}
function Ae(e) {
  const t = Oe(), n = M(e);
  return n.transform !== "none" || n.perspective !== "none" || (n.containerType ? n.containerType !== "normal" : false) || !t && (n.backdropFilter ? n.backdropFilter !== "none" : false) || !t && (n.filter ? n.filter !== "none" : false) || ["transform", "perspective", "filter"].some((i) => (n.willChange || "").includes(i)) || ["paint", "layout", "strict", "content"].some((i) => (n.contain || "").includes(i));
}
function qt(e) {
  let t = X(e);
  for (; z(t) && !ee(t); ) {
    if (Ae(t))
      return t;
    t = X(t);
  }
  return null;
}
function Oe() {
  return typeof CSS > "u" || !CSS.supports ? false : CSS.supports("-webkit-backdrop-filter", "none");
}
function ee(e) {
  return ["html", "body", "#document"].includes(te(e));
}
function M(e) {
  return N(e).getComputedStyle(e);
}
function me(e) {
  return _(e) ? {
    scrollLeft: e.scrollLeft,
    scrollTop: e.scrollTop
  } : {
    scrollLeft: e.pageXOffset,
    scrollTop: e.pageYOffset
  };
}
function X(e) {
  if (te(e) === "html")
    return e;
  const t = e.assignedSlot || e.parentNode || $e(e) && e.host || U(e);
  return $e(t) ? t.host : t;
}
function Ge(e) {
  const t = X(e);
  return ee(t) ? e.ownerDocument ? e.ownerDocument.body : e.body : z(t) && se(t) ? t : Ge(t);
}
function ie(e, t, n) {
  var i;
  t === void 0 && (t = []), n === void 0 && (n = true);
  const o = Ge(e), r = o === ((i = e.ownerDocument) == null ? void 0 : i.body), s = N(o);
  return r ? t.concat(s, s.visualViewport || [], se(o) ? o : [], s.frameElement && n ? ie(s.frameElement) : []) : t.concat(o, ie(o, [], n));
}
function Ke(e) {
  const t = M(e);
  let n = parseFloat(t.width) || 0, i = parseFloat(t.height) || 0;
  const o = z(e), r = o ? e.offsetWidth : n, s = o ? e.offsetHeight : i, l = ae(n) !== r || ae(i) !== s;
  return l && (n = r, i = s), {
    width: n,
    height: i,
    $: l
  };
}
function Te(e) {
  return _(e) ? e : e.contextElement;
}
function J2(e) {
  const t = Te(e);
  if (!z(t))
    return Y(1);
  const n = t.getBoundingClientRect(), {
    width: i,
    height: o,
    $: r
  } = Ke(t);
  let s = (r ? ae(n.width) : n.width) / i, l = (r ? ae(n.height) : n.height) / o;
  return (!s || !Number.isFinite(s)) && (s = 1), (!l || !Number.isFinite(l)) && (l = 1), {
    x: s,
    y: l
  };
}
var Gt = Y(0);
function Qe(e) {
  const t = N(e);
  return !Oe() || !t.visualViewport ? Gt : {
    x: t.visualViewport.offsetLeft,
    y: t.visualViewport.offsetTop
  };
}
function Kt(e, t, n) {
  return t === void 0 && (t = false), !n || t && n !== N(e) ? false : t;
}
function G(e, t, n, i) {
  t === void 0 && (t = false), n === void 0 && (n = false);
  const o = e.getBoundingClientRect(), r = Te(e);
  let s = Y(1);
  t && (i ? _(i) && (s = J2(i)) : s = J2(e));
  const l = Kt(r, n, i) ? Qe(r) : Y(0);
  let f = (o.left + l.x) / s.x, c = (o.top + l.y) / s.y, u = o.width / s.x, d = o.height / s.y;
  if (r) {
    const g = N(r), m = i && _(i) ? N(i) : i;
    let a = g, h = a.frameElement;
    for (; h && i && m !== a; ) {
      const v = J2(h), w = h.getBoundingClientRect(), y = M(h), b2 = w.left + (h.clientLeft + parseFloat(y.paddingLeft)) * v.x, C = w.top + (h.clientTop + parseFloat(y.paddingTop)) * v.y;
      f *= v.x, c *= v.y, u *= v.x, d *= v.y, f += b2, c += C, a = N(h), h = a.frameElement;
    }
  }
  return ue({
    width: u,
    height: d,
    x: f,
    y: c
  });
}
var Qt = [":popover-open", ":modal"];
function Re(e) {
  return Qt.some((t) => {
    try {
      return e.matches(t);
    } catch {
      return false;
    }
  });
}
function Jt(e) {
  let {
    elements: t,
    rect: n,
    offsetParent: i,
    strategy: o
  } = e;
  const r = o === "fixed", s = U(i), l = t ? Re(t.floating) : false;
  if (i === s || l && r)
    return n;
  let f = {
    scrollLeft: 0,
    scrollTop: 0
  }, c = Y(1);
  const u = Y(0), d = z(i);
  if ((d || !d && !r) && ((te(i) !== "body" || se(s)) && (f = me(i)), z(i))) {
    const g = G(i);
    c = J2(i), u.x = g.x + i.clientLeft, u.y = g.y + i.clientTop;
  }
  return {
    width: n.width * c.x,
    height: n.height * c.y,
    x: n.x * c.x - f.scrollLeft * c.x + u.x,
    y: n.y * c.y - f.scrollTop * c.y + u.y
  };
}
function Zt(e) {
  return Array.from(e.getClientRects());
}
function Je(e) {
  return G(U(e)).left + me(e).scrollLeft;
}
function en(e) {
  const t = U(e), n = me(e), i = e.ownerDocument.body, o = q(t.scrollWidth, t.clientWidth, i.scrollWidth, i.clientWidth), r = q(t.scrollHeight, t.clientHeight, i.scrollHeight, i.clientHeight);
  let s = -n.scrollLeft + Je(e);
  const l = -n.scrollTop;
  return M(i).direction === "rtl" && (s += q(t.clientWidth, i.clientWidth) - o), {
    width: o,
    height: r,
    x: s,
    y: l
  };
}
function tn(e, t) {
  const n = N(e), i = U(e), o = n.visualViewport;
  let r = i.clientWidth, s = i.clientHeight, l = 0, f = 0;
  if (o) {
    r = o.width, s = o.height;
    const c = Oe();
    (!c || c && t === "fixed") && (l = o.offsetLeft, f = o.offsetTop);
  }
  return {
    width: r,
    height: s,
    x: l,
    y: f
  };
}
function nn(e, t) {
  const n = G(e, true, t === "fixed"), i = n.top + e.clientTop, o = n.left + e.clientLeft, r = z(e) ? J2(e) : Y(1), s = e.clientWidth * r.x, l = e.clientHeight * r.y, f = o * r.x, c = i * r.y;
  return {
    width: s,
    height: l,
    x: f,
    y: c
  };
}
function ke(e, t, n) {
  let i;
  if (t === "viewport")
    i = tn(e, n);
  else if (t === "document")
    i = en(U(e));
  else if (_(t))
    i = nn(t, n);
  else {
    const o = Qe(e);
    i = {
      ...t,
      x: t.x - o.x,
      y: t.y - o.y
    };
  }
  return ue(i);
}
function Ze(e, t) {
  const n = X(e);
  return n === t || !_(n) || ee(n) ? false : M(n).position === "fixed" || Ze(n, t);
}
function on(e, t) {
  const n = t.get(e);
  if (n)
    return n;
  let i = ie(e, [], false).filter((l) => _(l) && te(l) !== "body"), o = null;
  const r = M(e).position === "fixed";
  let s = r ? X(e) : e;
  for (; _(s) && !ee(s); ) {
    const l = M(s), f = Ae(s);
    !f && l.position === "fixed" && (o = null), (r ? !f && !o : !f && l.position === "static" && !!o && ["absolute", "fixed"].includes(o.position) || se(s) && !f && Ze(e, s)) ? i = i.filter((u) => u !== s) : o = l, s = X(s);
  }
  return t.set(e, i), i;
}
function rn(e) {
  let {
    element: t,
    boundary: n,
    rootBoundary: i,
    strategy: o
  } = e;
  const s = [...n === "clippingAncestors" ? Re(t) ? [] : on(t, this._c) : [].concat(n), i], l = s[0], f = s.reduce((c, u) => {
    const d = ke(t, u, o);
    return c.top = q(d.top, c.top), c.right = Z(d.right, c.right), c.bottom = Z(d.bottom, c.bottom), c.left = q(d.left, c.left), c;
  }, ke(t, l, o));
  return {
    width: f.right - f.left,
    height: f.bottom - f.top,
    x: f.left,
    y: f.top
  };
}
function sn(e) {
  const {
    width: t,
    height: n
  } = Ke(e);
  return {
    width: t,
    height: n
  };
}
function ln(e, t, n) {
  const i = z(t), o = U(t), r = n === "fixed", s = G(e, true, r, t);
  let l = {
    scrollLeft: 0,
    scrollTop: 0
  };
  const f = Y(0);
  if (i || !i && !r)
    if ((te(t) !== "body" || se(o)) && (l = me(t)), i) {
      const d = G(t, true, r, t);
      f.x = d.x + t.clientLeft, f.y = d.y + t.clientTop;
    } else
      o && (f.x = Je(o));
  const c = s.left + l.scrollLeft - f.x, u = s.top + l.scrollTop - f.y;
  return {
    x: c,
    y: u,
    width: s.width,
    height: s.height
  };
}
function ve(e) {
  return M(e).position === "static";
}
function Me(e, t) {
  return !z(e) || M(e).position === "fixed" ? null : t ? t(e) : e.offsetParent;
}
function et(e, t) {
  const n = N(e);
  if (Re(e))
    return n;
  if (!z(e)) {
    let o = X(e);
    for (; o && !ee(o); ) {
      if (_(o) && !ve(o))
        return o;
      o = X(o);
    }
    return n;
  }
  let i = Me(e, t);
  for (; i && Xt(i) && ve(i); )
    i = Me(i, t);
  return i && ee(i) && ve(i) && !Ae(i) ? n : i || qt(e) || n;
}
var an = async function(e) {
  const t = this.getOffsetParent || et, n = this.getDimensions, i = await n(e.floating);
  return {
    reference: ln(e.reference, await t(e.floating), e.strategy),
    floating: {
      x: 0,
      y: 0,
      width: i.width,
      height: i.height
    }
  };
};
function cn(e) {
  return M(e).direction === "rtl";
}
var fn = {
  convertOffsetParentRelativeRectToViewportRelativeRect: Jt,
  getDocumentElement: U,
  getClippingRect: rn,
  getOffsetParent: et,
  getElementRects: an,
  getClientRects: Zt,
  getDimensions: sn,
  getScale: J2,
  isElement: _,
  isRTL: cn
};
function un(e, t) {
  let n = null, i;
  const o = U(e);
  function r() {
    var l;
    clearTimeout(i), (l = n) == null || l.disconnect(), n = null;
  }
  function s(l, f) {
    l === void 0 && (l = false), f === void 0 && (f = 1), r();
    const {
      left: c,
      top: u,
      width: d,
      height: g
    } = e.getBoundingClientRect();
    if (l || t(), !d || !g)
      return;
    const m = le(u), a = le(o.clientWidth - (c + d)), h = le(o.clientHeight - (u + g)), v = le(c), y = {
      rootMargin: -m + "px " + -a + "px " + -h + "px " + -v + "px",
      threshold: q(0, Z(1, f)) || 1
    };
    let b2 = true;
    function C(A2) {
      const O = A2[0].intersectionRatio;
      if (O !== f) {
        if (!b2)
          return s();
        O ? s(false, O) : i = setTimeout(() => {
          s(false, 1e-7);
        }, 1e3);
      }
      b2 = false;
    }
    try {
      n = new IntersectionObserver(C, {
        ...y,
        root: o.ownerDocument
      });
    } catch {
      n = new IntersectionObserver(C, y);
    }
    n.observe(e);
  }
  return s(true), r;
}
function dn(e, t, n, i) {
  i === void 0 && (i = {});
  const {
    ancestorScroll: o = true,
    ancestorResize: r = true,
    elementResize: s = typeof ResizeObserver == "function",
    layoutShift: l = typeof IntersectionObserver == "function",
    animationFrame: f = false
  } = i, c = Te(e), u = o || r ? [...c ? ie(c) : [], ...ie(t)] : [];
  u.forEach((w) => {
    o && w.addEventListener("scroll", n, {
      passive: true
    }), r && w.addEventListener("resize", n);
  });
  const d = c && l ? un(c, n) : null;
  let g = -1, m = null;
  s && (m = new ResizeObserver((w) => {
    let [y] = w;
    y && y.target === c && m && (m.unobserve(t), cancelAnimationFrame(g), g = requestAnimationFrame(() => {
      var b2;
      (b2 = m) == null || b2.observe(t);
    })), n();
  }), c && !f && m.observe(c), m.observe(t));
  let a, h = f ? G(e) : null;
  f && v();
  function v() {
    const w = G(e);
    h && (w.x !== h.x || w.y !== h.y || w.width !== h.width || w.height !== h.height) && n(), h = w, a = requestAnimationFrame(v);
  }
  return n(), () => {
    var w;
    u.forEach((y) => {
      o && y.removeEventListener("scroll", n), r && y.removeEventListener("resize", n);
    }), d == null || d(), (w = m) == null || w.disconnect(), m = null, f && cancelAnimationFrame(a);
  };
}
var mn = Ut;
var pn = _t;
var hn = Yt;
var gn = zt;
var vn = It;
var wn = Ht;
var yn = (e, t, n) => {
  const i = /* @__PURE__ */ new Map(), o = {
    platform: fn,
    ...n
  }, r = {
    ...o.platform,
    _c: i
  };
  return jt(e, t, {
    ...o,
    platform: r
  });
};
function xn(e) {
  return tt(e) ? (e.nodeName || "").toLowerCase() : "#document";
}
function bn(e) {
  var t;
  return (e == null || (t = e.ownerDocument) == null ? void 0 : t.defaultView) || window;
}
function tt(e) {
  return e instanceof Node || e instanceof bn(e).Node;
}
function Cn(e) {
  return e != null && typeof e == "object" && "$el" in e;
}
function xe(e) {
  if (Cn(e)) {
    const t = e.$el;
    return tt(t) && xn(t) === "#comment" ? null : t;
  }
  return e;
}
function An(e) {
  return {
    name: "arrow",
    options: e,
    fn(t) {
      const n = xe(I(e.element));
      return n == null ? {} : wn({
        element: n,
        padding: e.padding
      }).fn(t);
    }
  };
}
function nt(e) {
  return typeof window > "u" ? 1 : (e.ownerDocument.defaultView || window).devicePixelRatio || 1;
}
function je(e, t) {
  const n = nt(e);
  return Math.round(t * n) / n;
}
function On(e, t, n) {
  n === void 0 && (n = {});
  const i = n.whileElementsMounted, o = F(() => {
    var p;
    return (p = I(n.open)) != null ? p : true;
  }), r = F(() => I(n.middleware)), s = F(() => {
    var p;
    return (p = I(n.placement)) != null ? p : "bottom";
  }), l = F(() => {
    var p;
    return (p = I(n.strategy)) != null ? p : "absolute";
  }), f = F(() => {
    var p;
    return (p = I(n.transform)) != null ? p : true;
  }), c = F(() => xe(e.value)), u = F(() => xe(t.value)), d = y2(0), g = y2(0), m = y2(l.value), a = y2(s.value), h = rr({}), v = y2(false), w = F(() => {
    const p = {
      position: m.value,
      left: "0",
      top: "0"
    };
    if (!u.value)
      return p;
    const T = je(u.value, d.value), L = je(u.value, g.value);
    return f.value ? {
      ...p,
      transform: "translate(" + T + "px, " + L + "px)",
      ...nt(u.value) >= 1.5 && {
        willChange: "transform"
      }
    } : {
      position: m.value,
      left: T + "px",
      top: L + "px"
    };
  });
  let y;
  function b2() {
    c.value == null || u.value == null || yn(c.value, u.value, {
      middleware: r.value,
      placement: s.value,
      strategy: l.value
    }).then((p) => {
      d.value = p.x, g.value = p.y, m.value = p.strategy, a.value = p.placement, h.value = p.middlewareData, v.value = true;
    });
  }
  function C() {
    typeof y == "function" && (y(), y = void 0);
  }
  function A2() {
    if (C(), i === void 0) {
      b2();
      return;
    }
    if (c.value != null && u.value != null) {
      y = i(c.value, u.value, b2);
      return;
    }
  }
  function O() {
    o.value || (v.value = false);
  }
  return p3([r, s, l], b2, {
    flush: "sync"
  }), p3([c, u], A2, {
    flush: "sync"
  }), p3(o, O, {
    flush: "sync"
  }), wC() && xC(C), {
    x: KC(d),
    y: KC(g),
    strategy: KC(m),
    placement: KC(a),
    middlewareData: KC(h),
    isPositioned: KC(v),
    floatingStyles: w,
    update: b2
  };
}
var Tn = Object.defineProperty;
var Rn = (e, t, n) => t in e ? Tn(e, t, { enumerable: true, configurable: true, writable: true, value: n }) : e[t] = n;
var Sn = (e, t, n) => (Rn(e, typeof t != "symbol" ? t + "" : t, n), n);
function re(e) {
  return e == null || e.value == null ? null : e.value instanceof Node ? e.value : "$el" in e.value && e.value.$el ? re(y2(e.value.$el)) : "getBoundingClientRect" in e.value ? e.value : null;
}
function ot(e) {
  return e.reduce((t, n) => n.type === U2 ? t.concat(ot(n.children)) : t.concat(n), []);
}
function En(e) {
  return e == null ? false : typeof e.type == "string" || typeof e.type == "object" || typeof e.type == "function";
}
function He(e) {
  return e = I(e), e && (e == null ? void 0 : e.nodeType) !== Node.COMMENT_NODE;
}
var Pn = class {
  constructor() {
    Sn(this, "current", this.detect());
  }
  set(t) {
    this.current !== t && (this.current = t);
  }
  reset() {
    this.set(this.detect());
  }
  get isServer() {
    return this.current === "server";
  }
  get isClient() {
    return this.current === "client";
  }
  detect() {
    return typeof window > "u" || typeof document > "u" ? "server" : "client";
  }
};
var Se = new Pn();
function Ln(e) {
  if (Se.isServer)
    return null;
  if (e instanceof Node)
    return e.ownerDocument;
  if (Object.prototype.hasOwnProperty.call(e, "value")) {
    const t = re(e);
    if (t)
      return t.ownerDocument;
  }
  return document;
}
function Fn(e, t) {
  !t.vueTransition && (t.transitionName || t.transitionType) && console.warn(`[headlessui-float]: <${e} /> pass "transition-name" or "transition-type" prop, must be set "vue-transition" prop.`);
}
function Bn(e, t, n, i, o) {
  p3([
    () => o.offset,
    () => o.flip,
    () => o.shift,
    () => o.autoPlacement,
    () => o.arrow,
    () => o.hide,
    () => o.middleware
  ], () => {
    const r = [];
    (typeof o.offset == "number" || typeof o.offset == "object" || typeof o.offset == "function") && r.push(mn(o.offset)), (o.flip === true || typeof o.flip == "number" || typeof o.flip == "object") && r.push(gn({
      padding: typeof o.flip == "number" ? o.flip : void 0,
      ...typeof o.flip == "object" ? o.flip : {}
    })), (o.shift === true || typeof o.shift == "number" || typeof o.shift == "object") && r.push(hn({
      padding: typeof o.shift == "number" ? o.shift : void 0,
      ...typeof o.shift == "object" ? o.shift : {}
    })), (o.autoPlacement === true || typeof o.autoPlacement == "object") && r.push(pn(
      typeof o.autoPlacement == "object" ? o.autoPlacement : void 0
    )), r.push(...typeof o.middleware == "function" ? o.middleware({
      referenceEl: t,
      floatingEl: n
    }) : o.middleware || []), (o.arrow === true || typeof o.arrow == "number") && r.push(An({
      element: i,
      padding: o.arrow === true ? 0 : o.arrow
    })), (o.hide === true || typeof o.hide == "object" || Array.isArray(o.hide)) && (Array.isArray(o.hide) ? o.hide : [o.hide]).forEach((s) => {
      r.push(vn(
        typeof s == "object" ? s : void 0
      ));
    }), e.value = r;
  }, { immediate: true });
}
function Dn(e, t, n) {
  let i = () => {
  };
  s1(() => {
    if (e && Se.isClient && typeof ResizeObserver < "u" && t.value && t.value instanceof Element) {
      const o = new ResizeObserver(([r]) => {
        n.value = r.borderBoxSize.reduce((s, { inlineSize: l }) => s + l, 0);
      });
      o.observe(t.value), i = () => {
        o.disconnect(), n.value = null;
      };
    }
  }), U0(() => {
    i();
  });
}
var Nn = (e) => {
  switch (e) {
    case "top":
      return "origin-bottom";
    case "bottom":
      return "origin-top";
    case "left":
      return "origin-right";
    case "right":
      return "origin-left";
    case "top-start":
    case "right-end":
      return "origin-bottom-left";
    case "top-end":
    case "left-end":
      return "origin-bottom-right";
    case "right-start":
    case "bottom-start":
      return "origin-top-left";
    case "left-start":
    case "bottom-end":
      return "origin-top-right";
    default:
      return "origin-center";
  }
};
function $n(e, t) {
  const n = F(() => {
    if (typeof e.originClass == "function")
      return e.originClass(t.value);
    if (typeof e.originClass == "string")
      return e.originClass;
    if (e.tailwindcssOriginClass)
      return Nn(t.value);
  }), i = F(
    () => e.enter || n.value ? `${e.enter || ""} ${n.value || ""}` : void 0
  ), o = F(
    () => e.leave || n.value ? `${e.leave || ""} ${n.value || ""}` : void 0
  );
  return { originClassRef: n, enterActiveClassRef: i, leaveActiveClassRef: o };
}
function it(e, t, ...n) {
  if (e in t) {
    const o = t[e];
    return typeof o == "function" ? o(...n) : o;
  }
  const i = new Error(
    `Tried to handle "${e}" but there is no handler defined. Only defined handlers are: ${Object.keys(
      t
    ).map((o) => `"${o}"`).join(", ")}.`
  );
  throw Error.captureStackTrace && Error.captureStackTrace(i, it), i;
}
var We = [
  "[contentEditable=true]",
  "[tabindex]",
  "a[href]",
  "area[href]",
  "button:not([disabled])",
  "iframe",
  "input:not([disabled])",
  "select:not([disabled])",
  "textarea:not([disabled])"
].map(
  (e) => `${e}:not([tabindex='-1'])`
).join(",");
var rt = ((e) => (e[e.Strict = 0] = "Strict", e[e.Loose = 1] = "Loose", e))(rt || {});
function kn(e, t = 0) {
  var n;
  return e === ((n = Ln(e)) == null ? void 0 : n.body) ? false : it(t, {
    0() {
      return e.matches(We);
    },
    1() {
      let i = e;
      for (; i !== null; ) {
        if (i.matches(We))
          return true;
        i = i.parentElement;
      }
      return false;
    }
  });
}
function we(e, t, n) {
  Se.isServer || w3((i) => {
    document.addEventListener(e, t, n), i(() => document.removeEventListener(e, t, n));
  });
}
function Mn(e, t, n = F(() => true)) {
  function i(r, s) {
    if (!n.value || r.defaultPrevented)
      return;
    const l = s(r);
    if (l === null || !l.getRootNode().contains(l))
      return;
    const f = function c(u) {
      return typeof u == "function" ? c(u()) : Array.isArray(u) || u instanceof Set ? u : [u];
    }(e);
    for (const c of f) {
      if (c === null)
        continue;
      const u = c instanceof HTMLElement ? c : re(c);
      if (u != null && u.contains(l) || r.composed && r.composedPath().includes(u))
        return;
    }
    return !kn(l, rt.Loose) && l.tabIndex !== -1 && r.preventDefault(), t(r, l);
  }
  const o = y2(null);
  we("mousedown", (r) => {
    var s, l;
    n.value && (o.value = ((l = (s = r.composedPath) == null ? void 0 : s.call(r)) == null ? void 0 : l[0]) || r.target);
  }, true), we(
    "click",
    (r) => {
      o.value && (i(r, () => o.value), o.value = null);
    },
    true
  ), we("blur", (r) => i(
    r,
    () => window.document.activeElement instanceof HTMLIFrameElement ? window.document.activeElement : null
  ), true);
}
var jn = Symbol("ArrowContext");
var x = {
  as: {
    type: [String, Function],
    default: "template"
  },
  floatingAs: {
    type: [String, Function],
    default: "div"
  },
  show: {
    type: Boolean,
    default: null
  },
  placement: {
    type: String,
    default: "bottom-start"
  },
  strategy: {
    type: String,
    default: "absolute"
  },
  offset: [Number, Function, Object],
  shift: {
    type: [Boolean, Number, Object],
    default: false
  },
  flip: {
    type: [Boolean, Number, Object],
    default: false
  },
  arrow: {
    type: [Boolean, Number],
    default: false
  },
  autoPlacement: {
    type: [Boolean, Object],
    default: false
  },
  hide: {
    type: [Boolean, Object, Array],
    default: false
  },
  referenceHiddenClass: String,
  escapedClass: String,
  autoUpdate: {
    type: [Boolean, Object],
    default: true
  },
  zIndex: {
    type: [Number, String],
    default: 9999
  },
  vueTransition: {
    type: Boolean,
    default: false
  },
  transitionName: String,
  transitionType: String,
  enter: String,
  enterFrom: String,
  enterTo: String,
  leave: String,
  leaveFrom: String,
  leaveTo: String,
  originClass: [String, Function],
  tailwindcssOriginClass: {
    type: Boolean,
    default: false
  },
  portal: {
    type: Boolean,
    default: false
  },
  transform: {
    type: Boolean,
    default: false
  },
  adaptiveWidth: {
    type: [Boolean, Object],
    default: false
  },
  composable: {
    type: Boolean,
    default: false
  },
  dialog: {
    type: Boolean,
    default: false
  },
  middleware: {
    type: [Array, Function],
    default: () => []
  }
};
function Hn(e, t, n, i) {
  const { floatingRef: o, props: r, mounted: s, show: l, referenceHidden: f, escaped: c, placement: u, floatingStyles: d, referenceElWidth: g, updateFloating: m } = i, a = W8(
    { ...r, as: r.floatingAs },
    t
  ), { enterActiveClassRef: h, leaveActiveClassRef: v } = $n(a, u), w = {
    show: s.value ? a.show : false,
    enter: h.value,
    enterFrom: a.enterFrom,
    enterTo: a.enterTo,
    leave: v.value,
    leaveFrom: a.leaveFrom,
    leaveTo: a.leaveTo,
    onBeforeEnter() {
      l.value = true;
    },
    onAfterLeave() {
      l.value = false;
    }
  }, y = {
    name: a.transitionName,
    type: a.transitionType,
    appear: true,
    ...a.transitionName ? {} : {
      enterActiveClass: h.value,
      enterFromClass: a.enterFrom,
      enterToClass: a.enterTo,
      leaveActiveClass: v.value,
      leaveFromClass: a.leaveFrom,
      leaveToClass: a.leaveTo
    },
    onBeforeEnter() {
      l.value = true;
    },
    onAfterLeave() {
      l.value = false;
    }
  }, b2 = {
    class: [
      f.value ? a.referenceHiddenClass : void 0,
      c.value ? a.escapedClass : void 0
    ].filter((p) => !!p).join(" "),
    style: {
      ...d.value,
      zIndex: a.zIndex
    }
  };
  if (a.adaptiveWidth && typeof g.value == "number") {
    const p = {
      attribute: "width",
      ...typeof a.adaptiveWidth == "object" ? a.adaptiveWidth : {}
    };
    b2.style[p.attribute] = `${g.value}px`;
  }
  function C(p) {
    return a.portal ? s.value ? p1(DL, () => p) : M2() : p;
  }
  function A2(p) {
    const T = W8(
      b2,
      n,
      a.dialog ? {} : { ref: o }
    );
    return a.as === "template" ? p : typeof a.as == "string" ? p1(a.as, T, p) : p1(a.as, T, () => p);
  }
  function O() {
    function p() {
      var T;
      const L = a.as === "template" ? W8(
        b2,
        n,
        a.dialog ? {} : { ref: o }
      ) : null, S = Z3(e, L);
      return ((T = e.props) == null ? void 0 : T.unmount) === false ? (m(), S) : a.vueTransition && a.show === false ? M2() : S;
    }
    return s.value ? a.vueTransition ? p1(n5, {
      ...a.dialog ? { ref: o } : {},
      ...y
    }, p) : p1(a.transitionChild ? q6 : qL, {
      key: `placement-${u.value}`,
      ...a.dialog ? { ref: o } : {},
      as: "template",
      ...w
    }, p) : M2();
  }
  return C(
    A2(
      O()
    )
  );
}
function Wn(e, t, n, i, o) {
  const r = y2(false), s = lr(i, "placement"), l = lr(i, "strategy"), f = rr({}), c = y2(void 0), u = y2(void 0), d = y2(null), g = y2(void 0), m = y2(void 0), a = F(() => re(t)), h = F(() => re(n)), v = F(
    () => He(a) && He(h)
  ), { placement: w, middlewareData: y, isPositioned: b2, floatingStyles: C, update: A2 } = On(a, h, {
    placement: s,
    strategy: l,
    middleware: f,
    transform: i.dialog ? false : i.transform,
    whileElementsMounted: i.dialog ? () => () => {
    } : void 0
  }), O = y2(null);
  s1(() => {
    r.value = true;
  }), p3(e, (R, D) => {
    R && !D ? o("show") : !R && D && o("hide");
  }, { immediate: true });
  function p() {
    v.value && (A2(), o("update"));
  }
  p3([s, l, f], p, { flush: "sync" }), Bn(
    f,
    a,
    h,
    d,
    i
  ), p3([y, () => i.hide, b2], () => {
    var R, D;
    (i.hide === true || typeof i.hide == "object" || Array.isArray(i.hide)) && (c.value = ((R = y.value.hide) == null ? void 0 : R.referenceHidden) || !b2.value, u.value = (D = y.value.hide) == null ? void 0 : D.escaped);
  }), p3(y, () => {
    const R = y.value.arrow;
    g.value = R == null ? void 0 : R.x, m.value = R == null ? void 0 : R.y;
  }), Dn(!!i.adaptiveWidth, a, O), p3([e, v], async (R, D, F2) => {
    if (await N4(), e.value && v.value && i.autoUpdate) {
      const $ = dn(
        a.value,
        h.value,
        p,
        typeof i.autoUpdate == "object" ? i.autoUpdate : void 0
      );
      F2($);
    }
  }, { flush: "post", immediate: true });
  const T = y2(true);
  p3(a, () => {
    !(a.value instanceof Element) && v.value && T.value && (T.value = false, window.requestAnimationFrame(() => {
      T.value = true, p();
    }));
  }, { flush: "sync" });
  const L = {
    referenceRef: t,
    placement: w
  }, S = {
    floatingRef: n,
    props: i,
    mounted: r,
    show: e,
    referenceHidden: c,
    escaped: u,
    placement: w,
    floatingStyles: C,
    referenceElWidth: O,
    updateFloating: p
  }, B = {
    ref: d,
    placement: w,
    x: g,
    y: m
  };
  return L3(jn, B), { referenceApi: L, floatingApi: S, arrowApi: B, placement: w, referenceEl: a, floatingEl: h, middlewareData: y, update: p };
}
({
  ...x.as
});
var _n = {
  as: x.as,
  show: x.show,
  placement: x.placement,
  strategy: x.strategy,
  offset: x.offset,
  shift: x.shift,
  flip: x.flip,
  arrow: x.arrow,
  autoPlacement: x.autoPlacement,
  autoUpdate: x.autoUpdate,
  zIndex: x.zIndex,
  vueTransition: x.vueTransition,
  transitionName: x.transitionName,
  transitionType: x.transitionType,
  enter: x.enter,
  enterFrom: x.enterFrom,
  enterTo: x.enterTo,
  leave: x.leave,
  leaveFrom: x.leaveFrom,
  leaveTo: x.leaveTo,
  originClass: x.originClass,
  tailwindcssOriginClass: x.tailwindcssOriginClass,
  portal: x.portal,
  transform: x.transform,
  middleware: x.middleware
};
var zn = {
  name: "FloatVirtual",
  inheritAttrs: false,
  props: _n,
  emits: ["initial", "show", "hide", "update"],
  setup(e, { emit: t, slots: n, attrs: i }) {
    var u;
    Fn("FloatVirtual", e);
    const o = y2((u = e.show) != null ? u : false), r = y2({
      getBoundingClientRect() {
        return {
          x: 0,
          y: 0,
          top: 0,
          left: 0,
          bottom: 0,
          right: 0,
          width: 0,
          height: 0
        };
      }
    }), s = y2(null), {
      floatingApi: l,
      placement: f
    } = Wn(o, r, s, e, t);
    p3(() => e.show, () => {
      var d;
      o.value = (d = e.show) != null ? d : false;
    });
    function c() {
      o.value = false;
    }
    return t("initial", {
      show: o,
      placement: f,
      reference: r,
      floating: s
    }), () => {
      if (!n.default)
        return;
      const d = {
        placement: f.value,
        close: c
      }, [g] = ot(n.default(d)).filter(En);
      return Hn(
        g,
        {
          as: e.as,
          show: o.value
        },
        i,
        l
      );
    };
  }
};
x.as, x.placement, x.strategy, x.offset, x.shift, {
  ...x.flip
}, x.arrow, x.autoPlacement, x.autoUpdate, x.zIndex, x.vueTransition, x.transitionName, x.transitionType, x.enter, x.enterFrom, x.enterTo, x.leave, x.leaveFrom, x.leaveTo, x.originClass, x.tailwindcssOriginClass, x.transform, x.middleware;
var In = { class: "flex bg-white shadow-md z-10 rounded-md p-1" };
var Vn = ["onClick"];
var Yn = q2({
  __name: "StylePanel",
  setup(e) {
    YN({ WATCH_ARRAY: false });
    const t = y2({ value: null }), n = I3(), i = F(
      () => n.getters.onContentChange || (() => {
      })
    ), o = F(
      () => cL(n.getters.diagramElement) + Sf
    ), r = F(() => n.getters.code), s = (d) => {
      n.dispatch("updateCode", { code: d }), i.value(d);
    }, l = y2([]);
    let f;
    const c = ({ show: d, reference: g, floating: m }) => {
      let a, h, v, w, y, b2;
      n.commit("onMessageClick", (C, A2) => {
        var O;
        if (a = C.value.start.start, h = Yl(r.value, a), v = QN(r.value, a), w = ((O = r.value.slice(h).match(/^\s*/)) == null ? void 0 : O[0]) || "", y = v.trim().startsWith("//"), y) {
          const p = v.trimStart().slice(2).trimStart(), T = p.indexOf("["), L = p.indexOf("]");
          b2 = Boolean(T === 0 && L), b2 ? l.value = p.slice(T + 1, L).split(",").map((S) => S.trim()) : l.value = [];
        }
        g.value = {
          getBoundingClientRect: () => A2.getBoundingClientRect()
        }, t.value = C, d.value = true;
      }), Mn(
        m,
        () => {
          d.value = false, l.value = [];
        },
        F(() => d.value)
      ), f = (C) => {
        var A2;
        if (d.value = false, !!t.value.value)
          if (y) {
            let O = "";
            if (b2) {
              let p;
              l.value.includes(C) ? p = l.value.filter((T) => T !== C) : p = [...l.value, C], O = `${w}// [${p.filter(Boolean).join(", ")}] ${v.slice(v.indexOf("]") + 1).trimStart()}`;
            } else
              O = `${w}// [${C}] ${v.slice((((A2 = v.match(/\/\/*/)) == null ? void 0 : A2.index) || -2) + 2).trimStart()}`;
            O.endsWith(`
`) || (O += `
`), s(
              r.value.slice(0, Mf(r.value, a)) + O + r.value.slice(h)
            );
          } else
            s(
              r.value.slice(0, h) + `${w}// [${C}]
` + r.value.slice(h)
            );
      };
    }, u = [
      {
        name: "bold",
        content: "B",
        class: "font-bold"
      },
      {
        name: "italic",
        content: "I",
        class: "italic"
      },
      {
        name: "underline",
        content: "U",
        class: "underline"
      },
      {
        name: "strikethrough",
        content: "S",
        class: "line-through"
      }
    ];
    return (d, g) => (b(), S2(I(zn), {
      "vue-transition": "",
      id: "style-panel",
      key: "tool",
      onInitial: c,
      placement: "top",
      offset: 5,
      flip: { padding: I(o) },
      shift: "",
      zIndex: "30"
    }, {
      default: u3(() => [
        A("div", In, [
          (b(), J(U2, null, J3(u, (m) => A("div", {
            onClick: () => I(f)(m.class),
            key: m.name
          }, [
            A("div", {
              class: _2(["w-6 mx-1 py-1 rounded-md text-black text-center cursor-pointer hover:bg-gray-200", [
                m.class,
                { "bg-gray-100": l.value.includes(m.class) }
              ]])
            }, x1(m.content), 3)
          ], 8, Vn)), 64))
        ])
      ], void 0, true),
      _: 1
    }, 8, ["flip"]));
  }
});
export {
  Yn as default
};
//# sourceMappingURL=StylePanel.1d5cdf4e-5YTCEZP7.js.map
