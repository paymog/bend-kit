import Base
import ./markdown.bend as M
import ./LAWS.bend as Laws

def esc.clean(
  b1: Bool, b2: Bool, b3: Bool, b4: Bool, +c: U32, +r: String,
  e2: {b2 == U32.is_eq(c, 60) : Bool}, e3: {b3 == U32.is_eq(c, 62) : Bool}, e4: {b4 == U32.is_eq(c, 34) : Bool},
  ih: {Laws.clean(r) == True{} : Bool}
) -> {Laws.clean(M.esc.pick(b1, b2, b3, b4, Chr{c}, r)) == True{} : Bool}:
  match b1 b2 b3 b4:
    case True{} _ _ _:
      ih
    case False{} True{} _ _:
      ih
    case False{} False{} True{} _:
      ih
    case False{} False{} False{} True{}:
      ih
    case False{} False{} False{} False{}:
      %e2 : {Laws.clean.c(_, U32.is_eq(c, 62), U32.is_eq(c, 34), Laws.clean(r)) == True{} : Bool}
      %e3 : {Laws.clean.c(False{}, _, U32.is_eq(c, 34), Laws.clean(r)) == True{} : Bool}
      %e4 : {Laws.clean.c(False{}, False{}, _, Laws.clean(r)) == True{} : Bool}
      ih

def Laws.esc_clean(s):
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+y}, +t}:
      esc.clean(U32.is_eq(y, 38), U32.is_eq(y, 60), U32.is_eq(y, 62), U32.is_eq(y, 34), y, M.esc(t),
        {==}, {==}, {==}, Laws.esc_clean(t))

def esc.amp(
  b1: Bool, b2: Bool, b3: Bool, b4: Bool, +c: U32, +r: String,
  e1: {b1 == U32.is_eq(c, 38) : Bool},
  ih: {Laws.amp_ok(r) == True{} : Bool}
) -> {Laws.amp_ok(M.esc.pick(b1, b2, b3, b4, Chr{c}, r)) == True{} : Bool}:
  match b1 b2 b3 b4:
    case True{} _ _ _:
      ih
    case False{} True{} _ _:
      ih
    case False{} False{} True{} _:
      ih
    case False{} False{} False{} True{}:
      ih
    case False{} False{} False{} False{}:
      %e1 : {Laws.amp_ok.c(_, r, Laws.amp_ok(r)) == True{} : Bool}
      ih

def Laws.esc_amp_entity(s):
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+y}, +t}:
      esc.amp(U32.is_eq(y, 38), U32.is_eq(y, 60), U32.is_eq(y, 62), U32.is_eq(y, 34), y, M.esc(t),
        {==}, Laws.esc_amp_entity(t))

def Laws.safe_html_block():
  {==}

def Laws.safe_inline_html():
  {==}

def Laws.safe_javascript_link():
  {==}

def Laws.safe_autolink():
  {==}

def Laws.safe_data_png_kept():
  {==}

def Laws.safe_data_other():
  {==}

def Laws.safe_plain_link_kept():
  {==}

def Laws.gfm_table():
  {==}

def Laws.gfm_table_off():
  {==}

def Laws.gfm_task_list():
  {==}

def Laws.gfm_strikethrough():
  {==}

def Laws.gfm_strikethrough_off():
  {==}

def Laws.gfm_autolink():
  {==}

def Laws.gfm_autolink_safe():
  {==}

def Laws.gfm_tagfilter():
  {==}

def Laws.escape_text():
  {==}

def Laws.escape_code_span():
  {==}

def Laws.escape_code_block():
  {==}

def Laws.escape_title_quote():
  {==}

def Laws.escape_href():
  {==}

def Laws.escape_alt():
  {==}

def Laws.alt_line_breaks():
  {==}

def Laws.escape_entity_kept():
  {==}

def Laws.raw_html_kept():
  {==}

def Laws.spec_1():
  {==}

def Laws.spec_12():
  {==}

def Laws.spec_25():
  {==}

def Laws.spec_43():
  {==}

def Laws.spec_62():
  {==}

def Laws.spec_80():
  {==}

def Laws.spec_107():
  {==}

def Laws.spec_119():
  {==}

def Laws.spec_148():
  {==}

def Laws.spec_192():
  {==}

def Laws.spec_219():
  {==}

def Laws.spec_228():
  {==}

def Laws.spec_253():
  {==}

def Laws.spec_301():
  {==}

def Laws.spec_328():
  {==}

def Laws.spec_360():
  {==}

def Laws.spec_402():
  {==}

def Laws.spec_426():
  {==}

def Laws.spec_482():
  {==}

def Laws.spec_504():
  {==}

def Laws.spec_526():
  {==}

def Laws.spec_572():
  {==}

def Laws.spec_594():
  {==}

def Laws.spec_613():
  {==}

def Laws.spec_633():
  {==}
