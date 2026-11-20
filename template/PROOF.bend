import Base
import ./template.bend as T
import ./LAWS.bend as Laws

def esc.clean(
  amp: Bool, lt: Bool, gt: Bool, quot: Bool, apos: Bool, +c: U32, +r: String,
  elt: {lt == U32.is_eq(c, 60) : Bool}, egt: {gt == U32.is_eq(c, 62) : Bool},
  equot: {quot == U32.is_eq(c, 34) : Bool}, eapos: {apos == U32.is_eq(c, 39) : Bool},
  ih: {Laws.clean(r) == True{} : Bool}
) -> {Laws.clean(T.escape.pick(amp, lt, gt, quot, apos, Chr{c}, r)) == True{} : Bool}:
  match amp lt gt quot apos:
    case True{} _ _ _ _:
      ih
    case False{} True{} _ _ _:
      ih
    case False{} False{} True{} _ _:
      ih
    case False{} False{} False{} True{} _:
      ih
    case False{} False{} False{} False{} True{}:
      ih
    case False{} False{} False{} False{} False{}:
      %elt : {Laws.clean.c(_, U32.is_eq(c, 62), U32.is_eq(c, 34), U32.is_eq(c, 39), Laws.clean(r)) == True{} : Bool}
      %egt : {Laws.clean.c(False{}, _, U32.is_eq(c, 34), U32.is_eq(c, 39), Laws.clean(r)) == True{} : Bool}
      %equot : {Laws.clean.c(False{}, False{}, _, U32.is_eq(c, 39), Laws.clean(r)) == True{} : Bool}
      %eapos : {Laws.clean.c(False{}, False{}, False{}, _, Laws.clean(r)) == True{} : Bool}
      ih

def Laws.escape_clean(s):
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+y}, +t}:
      esc.clean(U32.is_eq(y, 38), U32.is_eq(y, 60), U32.is_eq(y, 62), U32.is_eq(y, 34), U32.is_eq(y, 39), y, T.escape(t),
        {==}, {==}, {==}, {==}, Laws.escape_clean(t))

def esc.amp(
  amp: Bool, lt: Bool, gt: Bool, quot: Bool, apos: Bool, +c: U32, +r: String,
  eamp: {amp == U32.is_eq(c, 38) : Bool},
  ih: {Laws.amp_ok(r) == True{} : Bool}
) -> {Laws.amp_ok(T.escape.pick(amp, lt, gt, quot, apos, Chr{c}, r)) == True{} : Bool}:
  match amp lt gt quot apos:
    case True{} _ _ _ _:
      ih
    case False{} True{} _ _ _:
      ih
    case False{} False{} True{} _ _:
      ih
    case False{} False{} False{} True{} _:
      ih
    case False{} False{} False{} False{} True{}:
      ih
    case False{} False{} False{} False{} False{}:
      %eamp : {Laws.amp_ok.c(_, r, Laws.amp_ok(r)) == True{} : Bool}
      ih

def Laws.escape_amp_entity(s):
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+y}, +t}:
      esc.amp(U32.is_eq(y, 38), U32.is_eq(y, 60), U32.is_eq(y, 62), U32.is_eq(y, 34), U32.is_eq(y, 39), y, T.escape(t),
        {==}, Laws.escape_amp_entity(t))

def Laws.escape_lt():
  {==}

def Laws.escape_gt():
  {==}

def Laws.escape_amp():
  {==}

def Laws.escape_quot():
  {==}

def Laws.escape_apos():
  {==}

def Laws.escape_entity_twice():
  {==}

def Laws.escape_plain():
  {==}

def Laws.var_escaped():
  {==}

def Laws.triple_raw():
  {==}

def Laws.amp_raw():
  {==}

def Laws.missing_empty():
  {==}

def Laws.dotted():
  {==}

def Laws.dotted_no_fallback():
  {==}

def Laws.loop():
  {==}

def Laws.section_map():
  {==}

def Laws.section_outer_lookup():
  {==}

def Laws.section_false():
  {==}

def Laws.section_empty_list():
  {==}

def Laws.inverted_empty():
  {==}

def Laws.comment():
  {==}

def Laws.standalone_lines():
  {==}

def Laws.inline_section_keeps_line():
  {==}

def Laws.unclosed_section():
  {==}

def Laws.mismatched_close():
  {==}

def Laws.unclosed_tag():
  {==}

def Laws.partial_without_map():
  {==}

def Laws.partial_missing():
  {==}

def Laws.partial_caller_context():
  {==}

def Laws.partial_in_loop():
  {==}

def Laws.partial_standalone_indent():
  {==}

def Laws.partial_recursion_capped():
  {==}

def Laws.partial_default_delims():
  {==}

def Laws.delims_switch():
  {==}

def Laws.delims_back():
  {==}

def Laws.delims_triple():
  {==}

def Laws.delims_standalone():
  {==}

def Laws.delims_bad():
  {==}
