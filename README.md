# commonmark-scribunto

A [CommonMark](https://spec.commonmark.org/0.31.2/) Markdown parser for MediaWiki, implemented as a Scribunto Lua module.

## Installation

Copy the module to `Module:Markdown` on your wiki.

## Usage

### In a template

```
{{#invoke:Markdown|main|1=Your **Markdown** here.}}
```

### From another module

```lua
local md = require('Module:Markdown')
local wikitext = md.parse(text, frame)
```

## Supported syntax

| Feature | Section |
|---|---|
| Backslash escapes | §2.4 |
| Thematic breaks (`---`, `***`, `___`) | §4.1 |
| ATX headings (`#` – `######`) | §4.2 |
| Setext headings | §4.3 |
| Indented code blocks | §4.4 |
| Fenced code blocks (` ``` ` and `~~~`) | §4.5 |
| Link reference definitions | §4.7 |
| Paragraphs | §4.8 |
| Block quotes | §5.1 |
| Lists — bullet and ordered, tight and loose, nested | §5.2 / 5.3 |
| Code spans | §6.1 |
| Emphasis and strong emphasis (`*`, `_`, `**`, `__`) | §6.2 |
| Links — inline, reference, collapsed, shortcut | §6.3 |
| Images | §6.4 |
| Autolinks | §6.5 |
| Hard line breaks | §6.7 |
| Soft line breaks | §6.8 |

## Known limitations

**Raw HTML (§6.6)** is intentionally not implemented. MediaWiki sanitizes user supplied HTML regardless of configuration, making passthrough unpredictable. Besides, it's pretty unsafe, no? Use wikitext or MediaWiki extension tags instead.

**Named entity references (§2.5)** are not decoded by the parser. MediaWiki's sanitizer decodes both named entities (`&copy;`) and numeric references (`&#42;`, `&#x2A;`) before render, so all valid references will display correctly. Structural use of entities such as `&#42;` in place of * for emphasis, however, is intentionally not supported per spec.

**Strip markers** (content inside `<ref>`, `<gallery>`, and other extension tags is processed by the MediaWiki parser before the module receives it, leaving opaque strip markers in the input). This means such tags inside Markdown passed to this module will not render correctly. `<nowiki>` is handled correctly mainly to handle signatures `~~~` where it is used for the code blocks which would otherwise be turned into signatures without `<nowiki>`.

**SyntaxHighlight** (`Extension:SyntaxHighlight`) must be installed for fenced and indented code blocks to render. It has been bundled with MediaWiki since 1.21 but still have to be manually turned on. Should be enabled by default on almost all wiki farms.

## License

[MIT](LICENSE)
