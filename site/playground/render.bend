import Base
import ../../markdown/markdown.bend as M

def render(s: String) -> String:
  M.to_html_with(M.Opts{True{}, True{}}, s)
