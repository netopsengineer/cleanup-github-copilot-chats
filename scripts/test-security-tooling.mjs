// Compatibility checks for patched transitive Markdown dependencies.
import assert from "node:assert/strict";
import { micromark } from "micromark";
import { math, mathHtml } from "micromark-extension-math";
import MarkdownIt from "markdown-it";
import { parse } from "smol-toml";

const options = { extensions: [math()], htmlExtensions: [mathHtml()] };
for (const source of ["Inline $x^2 + y^2 = z^2$.", "$$\n\\frac{1}{2}\n$$\n"]) {
  const html = micromark(source, options);
  assert.match(html, /katex/);
  assert.doesNotMatch(html, /katex-error/);
}
const unsafe = micromark("$\\href{javascript:alert(1)}{unsafe}$", options);
assert.doesNotMatch(unsafe, /href="javascript:/);
assert.equal(parse("answer = 42\n").answer, 42);
assert.match(new MarkdownIt().render("# Heading\n\n[link](https://example.com)\n"), /<h1>Heading<\/h1>/);
console.log("Patched Markdown/TOML dependencies and math integration passed.");
