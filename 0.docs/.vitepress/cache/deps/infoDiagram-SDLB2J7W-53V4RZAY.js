import {
  parse
} from "./chunk-UKD33F6C.js";
import "./chunk-H56O2442.js";
import "./chunk-GTI2RXWR.js";
import "./chunk-FWLFKXDS.js";
import "./chunk-H7QW5FLW.js";
import "./chunk-WT2YDN4O.js";
import "./chunk-ZMSCANQO.js";
import "./chunk-W4C6O4J6.js";
import {
  package_default
} from "./chunk-TTVNRHZ5.js";
import {
  selectSvgElement
} from "./chunk-62ASMOEL.js";
import {
  __name,
  configureSvgSize,
  log
} from "./chunk-ZB4E7I5C.js";
import "./chunk-2VRVB2MD.js";
import "./chunk-4UTD2NOI.js";
import "./chunk-FDBJFBLO.js";

// node_modules/mermaid/dist/chunks/mermaid.core/infoDiagram-SDLB2J7W.mjs
var parser = {
  parse: __name(async (input) => {
    const ast = await parse("info", input);
    log.debug(ast);
  }, "parse")
};
var DEFAULT_INFO_DB = { version: package_default.version };
var getVersion = __name(() => DEFAULT_INFO_DB.version, "getVersion");
var db = {
  getVersion
};
var draw = __name((text, id, version) => {
  log.debug("rendering info diagram\n" + text);
  const svg = selectSvgElement(id);
  configureSvgSize(svg, 100, 400, true);
  const group = svg.append("g");
  group.append("text").attr("x", 100).attr("y", 40).attr("class", "version").attr("font-size", 32).style("text-anchor", "middle").text(`v${version}`);
}, "draw");
var renderer = { draw };
var diagram = {
  parser,
  db,
  renderer
};
export {
  diagram
};
//# sourceMappingURL=infoDiagram-SDLB2J7W-53V4RZAY.js.map
