import Base
import ./markdown.bend as M

def doc() -> String:
  "# Notes & *ideas*\n\nA [link][home] and `<code>`.\n\n- one\n- two\n  > quoted **text**\n\n```js\nlet x = 1 < 2;\n```\n\n[home]: https://example.com/a?b=1&c=2 \"Home\"\n"

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(M.to_html(doc()))
