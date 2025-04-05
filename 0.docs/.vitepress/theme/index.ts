import DefaultTheme from "vitepress/theme";
import "@catppuccin/vitepress/theme/mocha/red.css";
import Mermaid from "./Mermaid.vue";

export default {
  ...DefaultTheme,
  enhanceApp({ app }) {
    app.component("Mermaid", Mermaid);
  },
};
