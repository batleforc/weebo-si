import "./chunk-FDBJFBLO.js";

// node_modules/@mermaid-js/mermaid-zenuml/dist/mermaid-zenuml.core.mjs
var id = "zenuml";
var detector = (txt) => {
  return /^\s*zenuml/.test(txt);
};
var loader = async () => {
  const { diagram } = await import("./zenuml-definition-ddfc84a5-TXRIDYAI.js");
  return { id, diagram };
};
var plugin = {
  id,
  detector,
  loader
};
export {
  plugin as default
};
//# sourceMappingURL=@mermaid-js_mermaid-zenuml.js.map
