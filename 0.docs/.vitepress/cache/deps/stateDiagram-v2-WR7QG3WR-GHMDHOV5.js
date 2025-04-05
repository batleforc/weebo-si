import {
  StateDB,
  stateDiagram_default,
  stateRenderer_v3_unified_default,
  styles_default
} from "./chunk-NLYYSZDI.js";
import "./chunk-ZBE77RWN.js";
import "./chunk-X67XYMTI.js";
import "./chunk-JDVQKAVM.js";
import "./chunk-SAISBUDQ.js";
import "./chunk-U2RRPCGG.js";
import "./chunk-DMRYYJ6I.js";
import "./chunk-2KLCM4H4.js";
import "./chunk-6PACEXUI.js";
import "./chunk-JPVFVS7W.js";
import "./chunk-LQRCPGYC.js";
import {
  __name
} from "./chunk-ZB4E7I5C.js";
import "./chunk-4UTD2NOI.js";
import "./chunk-FDBJFBLO.js";

// node_modules/mermaid/dist/chunks/mermaid.core/stateDiagram-v2-WR7QG3WR.mjs
var diagram = {
  parser: stateDiagram_default,
  get db() {
    return new StateDB(2);
  },
  renderer: stateRenderer_v3_unified_default,
  styles: styles_default,
  init: __name((cnf) => {
    if (!cnf.state) {
      cnf.state = {};
    }
    cnf.state.arrowMarkerAbsolute = cnf.arrowMarkerAbsolute;
  }, "init")
};
export {
  diagram
};
//# sourceMappingURL=stateDiagram-v2-WR7QG3WR-GHMDHOV5.js.map
