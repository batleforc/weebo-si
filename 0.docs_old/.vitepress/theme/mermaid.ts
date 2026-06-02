import mermaid, { type MermaidConfig } from "mermaid";
import zenuml from "@mermaid-js/mermaid-zenuml";

const init = mermaid.registerExternalDiagrams([zenuml]);

// https://icones.js.org/collection/mdi?s=laptop
mermaid.registerIconPacks([
  {
    name: "logos",
    loader: () => import("@iconify-json/logos").then((module) => module.icons),
  },
  {
    name: "mdi",
    loader: () => import("@iconify-json/mdi").then((module) => module.icons),
  },
]);

export const render = async (
  id: string,
  code: string,
  config: MermaidConfig
): Promise<string> => {
  await init;
  mermaid.initialize(config);
  let { svg } = await mermaid.render(id, code);
  let svg2 = svg;
  let iterMax = 5;
  do {
    let { svg: svg3 } = await mermaid.render(id, code);
    svg2 = svg3;
  } while (!svg2.includes("<g ") && iterMax-- >= 0);
  return svg2;
};
