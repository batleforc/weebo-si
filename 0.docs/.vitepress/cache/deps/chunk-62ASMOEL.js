import {
  __name,
  getConfig2,
  select_default
} from "./chunk-ZB4E7I5C.js";

// node_modules/mermaid/dist/chunks/mermaid.core/chunk-XYJ2X5CJ.mjs
var selectSvgElement = __name((id) => {
  var _a;
  const { securityLevel } = getConfig2();
  let root = select_default("body");
  if (securityLevel === "sandbox") {
    const sandboxElement = select_default(`#i${id}`);
    const doc = ((_a = sandboxElement.node()) == null ? void 0 : _a.contentDocument) ?? document;
    root = select_default(doc.body);
  }
  const svg = root.select(`#${id}`);
  return svg;
}, "selectSvgElement");

export {
  selectSvgElement
};
//# sourceMappingURL=chunk-62ASMOEL.js.map
