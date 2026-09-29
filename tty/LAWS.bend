import Base
import ./tty.bend as Tty

law narrow:
  {Tty.width("plain") == 5 : U32}

law wide:
  {Tty.width("A界") == 3 : U32}

law combining:
  {Tty.width("e\u{301}") == 1 : U32}

law padding_wide:
  {Tty.pad_right("界", 4) == "界  " : String}

law padding_combining:
  {Tty.pad_right("e\u{301}", 3) == "e\u{301}  " : String}

law no_negative_padding:
  {Tty.pad_right("界", 1) == "界" : String}

law no_color:
  {Tty.style(False{}, 31, "red") == "red" : String}

law ansi_red:
  {Tty.style(True{}, 31, "red") == "\u{1B}[31mred\u{1B}[0m" : String}
