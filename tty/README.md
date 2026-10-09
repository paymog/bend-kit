# Terminal text

```bend
import bend-kit-tty@0.1.0.1/tty.bend as Tty
import bend-kit-tty@0.1.0.1/text.bend as Text
```

`tty.bend` re-exports the text helpers it imports. `text.bend` is still a separate file if you want only width and style. Width uses `unicode` by the hash in `text.bend`.


`Tty.stdout_tty()` reports whether standard output is a terminal. `Tty.size()` returns `Some{(columns, rows)}` when its size can be read, or `None{}` for redirected output and unavailable dimensions. `Tty.color_enabled()` requires a terminal and the absence of `NO_COLOR`; even an empty `NO_COLOR` disables automatic color.

`Tty.auto_style(31, "error")` wraps text in red ANSI SGR when automatic color is enabled. `Tty.style(True{}, 1, text)` explicitly requests bold, while `style(False{}, …)` leaves the text unchanged. Pass an SGR code, not an escape string. Use `Tty.width(text)` and `Tty.pad_right(text, columns)` to align Unicode text by terminal columns rather than code points or UTF-8 bytes.

The width table uses Unicode 17 East Asian Width and grapheme clusters. Ambiguous-width characters count as one column; terminals in CJK locales can render them as two. Tabs and other controls do not model cursor movement. Measure and pad text before applying ANSI styling: `width` does not strip escape sequences.

`../scripts/check.sh tty` runs laws and basic runtime checks. `python3 effects_check.py` exercises both native and Bun effects using a redirected pipe, an 80×24 pseudo-terminal and `NO_COLOR`. Run `python3 bench/run.py` for the cross-language checksum and performance comparison.
