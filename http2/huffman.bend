# RFC 7541 Appendix B Huffman alphabet and streaming codec.
import Base
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes

type Code is Data:
  Code{bits: U32, width: U32}

def code(+octet: U32) -> Code:
  match octet:
    case 0:
      Code{8184, 13}
    case 1:
      Code{8388568, 23}
    case 2:
      Code{268435426, 28}
    case 3:
      Code{268435427, 28}
    case 4:
      Code{268435428, 28}
    case 5:
      Code{268435429, 28}
    case 6:
      Code{268435430, 28}
    case 7:
      Code{268435431, 28}
    case 8:
      Code{268435432, 28}
    case 9:
      Code{16777194, 24}
    case 10:
      Code{1073741820, 30}
    case 11:
      Code{268435433, 28}
    case 12:
      Code{268435434, 28}
    case 13:
      Code{1073741821, 30}
    case 14:
      Code{268435435, 28}
    case 15:
      Code{268435436, 28}
    case 16:
      Code{268435437, 28}
    case 17:
      Code{268435438, 28}
    case 18:
      Code{268435439, 28}
    case 19:
      Code{268435440, 28}
    case 20:
      Code{268435441, 28}
    case 21:
      Code{268435442, 28}
    case 22:
      Code{1073741822, 30}
    case 23:
      Code{268435443, 28}
    case 24:
      Code{268435444, 28}
    case 25:
      Code{268435445, 28}
    case 26:
      Code{268435446, 28}
    case 27:
      Code{268435447, 28}
    case 28:
      Code{268435448, 28}
    case 29:
      Code{268435449, 28}
    case 30:
      Code{268435450, 28}
    case 31:
      Code{268435451, 28}
    case 32:
      Code{20, 6}
    case 33:
      Code{1016, 10}
    case 34:
      Code{1017, 10}
    case 35:
      Code{4090, 12}
    case 36:
      Code{8185, 13}
    case 37:
      Code{21, 6}
    case 38:
      Code{248, 8}
    case 39:
      Code{2042, 11}
    case 40:
      Code{1018, 10}
    case 41:
      Code{1019, 10}
    case 42:
      Code{249, 8}
    case 43:
      Code{2043, 11}
    case 44:
      Code{250, 8}
    case 45:
      Code{22, 6}
    case 46:
      Code{23, 6}
    case 47:
      Code{24, 6}
    case 48:
      Code{0, 5}
    case 49:
      Code{1, 5}
    case 50:
      Code{2, 5}
    case 51:
      Code{25, 6}
    case 52:
      Code{26, 6}
    case 53:
      Code{27, 6}
    case 54:
      Code{28, 6}
    case 55:
      Code{29, 6}
    case 56:
      Code{30, 6}
    case 57:
      Code{31, 6}
    case 58:
      Code{92, 7}
    case 59:
      Code{251, 8}
    case 60:
      Code{32764, 15}
    case 61:
      Code{32, 6}
    case 62:
      Code{4091, 12}
    case 63:
      Code{1020, 10}
    case 64:
      Code{8186, 13}
    case 65:
      Code{33, 6}
    case 66:
      Code{93, 7}
    case 67:
      Code{94, 7}
    case 68:
      Code{95, 7}
    case 69:
      Code{96, 7}
    case 70:
      Code{97, 7}
    case 71:
      Code{98, 7}
    case 72:
      Code{99, 7}
    case 73:
      Code{100, 7}
    case 74:
      Code{101, 7}
    case 75:
      Code{102, 7}
    case 76:
      Code{103, 7}
    case 77:
      Code{104, 7}
    case 78:
      Code{105, 7}
    case 79:
      Code{106, 7}
    case 80:
      Code{107, 7}
    case 81:
      Code{108, 7}
    case 82:
      Code{109, 7}
    case 83:
      Code{110, 7}
    case 84:
      Code{111, 7}
    case 85:
      Code{112, 7}
    case 86:
      Code{113, 7}
    case 87:
      Code{114, 7}
    case 88:
      Code{252, 8}
    case 89:
      Code{115, 7}
    case 90:
      Code{253, 8}
    case 91:
      Code{8187, 13}
    case 92:
      Code{524272, 19}
    case 93:
      Code{8188, 13}
    case 94:
      Code{16380, 14}
    case 95:
      Code{34, 6}
    case 96:
      Code{32765, 15}
    case 97:
      Code{3, 5}
    case 98:
      Code{35, 6}
    case 99:
      Code{4, 5}
    case 100:
      Code{36, 6}
    case 101:
      Code{5, 5}
    case 102:
      Code{37, 6}
    case 103:
      Code{38, 6}
    case 104:
      Code{39, 6}
    case 105:
      Code{6, 5}
    case 106:
      Code{116, 7}
    case 107:
      Code{117, 7}
    case 108:
      Code{40, 6}
    case 109:
      Code{41, 6}
    case 110:
      Code{42, 6}
    case 111:
      Code{7, 5}
    case 112:
      Code{43, 6}
    case 113:
      Code{118, 7}
    case 114:
      Code{44, 6}
    case 115:
      Code{8, 5}
    case 116:
      Code{9, 5}
    case 117:
      Code{45, 6}
    case 118:
      Code{119, 7}
    case 119:
      Code{120, 7}
    case 120:
      Code{121, 7}
    case 121:
      Code{122, 7}
    case 122:
      Code{123, 7}
    case 123:
      Code{32766, 15}
    case 124:
      Code{2044, 11}
    case 125:
      Code{16381, 14}
    case 126:
      Code{8189, 13}
    case 127:
      Code{268435452, 28}
    case 128:
      Code{1048550, 20}
    case 129:
      Code{4194258, 22}
    case 130:
      Code{1048551, 20}
    case 131:
      Code{1048552, 20}
    case 132:
      Code{4194259, 22}
    case 133:
      Code{4194260, 22}
    case 134:
      Code{4194261, 22}
    case 135:
      Code{8388569, 23}
    case 136:
      Code{4194262, 22}
    case 137:
      Code{8388570, 23}
    case 138:
      Code{8388571, 23}
    case 139:
      Code{8388572, 23}
    case 140:
      Code{8388573, 23}
    case 141:
      Code{8388574, 23}
    case 142:
      Code{16777195, 24}
    case 143:
      Code{8388575, 23}
    case 144:
      Code{16777196, 24}
    case 145:
      Code{16777197, 24}
    case 146:
      Code{4194263, 22}
    case 147:
      Code{8388576, 23}
    case 148:
      Code{16777198, 24}
    case 149:
      Code{8388577, 23}
    case 150:
      Code{8388578, 23}
    case 151:
      Code{8388579, 23}
    case 152:
      Code{8388580, 23}
    case 153:
      Code{2097116, 21}
    case 154:
      Code{4194264, 22}
    case 155:
      Code{8388581, 23}
    case 156:
      Code{4194265, 22}
    case 157:
      Code{8388582, 23}
    case 158:
      Code{8388583, 23}
    case 159:
      Code{16777199, 24}
    case 160:
      Code{4194266, 22}
    case 161:
      Code{2097117, 21}
    case 162:
      Code{1048553, 20}
    case 163:
      Code{4194267, 22}
    case 164:
      Code{4194268, 22}
    case 165:
      Code{8388584, 23}
    case 166:
      Code{8388585, 23}
    case 167:
      Code{2097118, 21}
    case 168:
      Code{8388586, 23}
    case 169:
      Code{4194269, 22}
    case 170:
      Code{4194270, 22}
    case 171:
      Code{16777200, 24}
    case 172:
      Code{2097119, 21}
    case 173:
      Code{4194271, 22}
    case 174:
      Code{8388587, 23}
    case 175:
      Code{8388588, 23}
    case 176:
      Code{2097120, 21}
    case 177:
      Code{2097121, 21}
    case 178:
      Code{4194272, 22}
    case 179:
      Code{2097122, 21}
    case 180:
      Code{8388589, 23}
    case 181:
      Code{4194273, 22}
    case 182:
      Code{8388590, 23}
    case 183:
      Code{8388591, 23}
    case 184:
      Code{1048554, 20}
    case 185:
      Code{4194274, 22}
    case 186:
      Code{4194275, 22}
    case 187:
      Code{4194276, 22}
    case 188:
      Code{8388592, 23}
    case 189:
      Code{4194277, 22}
    case 190:
      Code{4194278, 22}
    case 191:
      Code{8388593, 23}
    case 192:
      Code{67108832, 26}
    case 193:
      Code{67108833, 26}
    case 194:
      Code{1048555, 20}
    case 195:
      Code{524273, 19}
    case 196:
      Code{4194279, 22}
    case 197:
      Code{8388594, 23}
    case 198:
      Code{4194280, 22}
    case 199:
      Code{33554412, 25}
    case 200:
      Code{67108834, 26}
    case 201:
      Code{67108835, 26}
    case 202:
      Code{67108836, 26}
    case 203:
      Code{134217694, 27}
    case 204:
      Code{134217695, 27}
    case 205:
      Code{67108837, 26}
    case 206:
      Code{16777201, 24}
    case 207:
      Code{33554413, 25}
    case 208:
      Code{524274, 19}
    case 209:
      Code{2097123, 21}
    case 210:
      Code{67108838, 26}
    case 211:
      Code{134217696, 27}
    case 212:
      Code{134217697, 27}
    case 213:
      Code{67108839, 26}
    case 214:
      Code{134217698, 27}
    case 215:
      Code{16777202, 24}
    case 216:
      Code{2097124, 21}
    case 217:
      Code{2097125, 21}
    case 218:
      Code{67108840, 26}
    case 219:
      Code{67108841, 26}
    case 220:
      Code{268435453, 28}
    case 221:
      Code{134217699, 27}
    case 222:
      Code{134217700, 27}
    case 223:
      Code{134217701, 27}
    case 224:
      Code{1048556, 20}
    case 225:
      Code{16777203, 24}
    case 226:
      Code{1048557, 20}
    case 227:
      Code{2097126, 21}
    case 228:
      Code{4194281, 22}
    case 229:
      Code{2097127, 21}
    case 230:
      Code{2097128, 21}
    case 231:
      Code{8388595, 23}
    case 232:
      Code{4194282, 22}
    case 233:
      Code{4194283, 22}
    case 234:
      Code{33554414, 25}
    case 235:
      Code{33554415, 25}
    case 236:
      Code{16777204, 24}
    case 237:
      Code{16777205, 24}
    case 238:
      Code{67108842, 26}
    case 239:
      Code{8388596, 23}
    case 240:
      Code{67108843, 26}
    case 241:
      Code{134217702, 27}
    case 242:
      Code{67108844, 26}
    case 243:
      Code{67108845, 26}
    case 244:
      Code{134217703, 27}
    case 245:
      Code{134217704, 27}
    case 246:
      Code{134217705, 27}
    case 247:
      Code{134217706, 27}
    case 248:
      Code{134217707, 27}
    case 249:
      Code{268435454, 28}
    case 250:
      Code{134217708, 27}
    case 251:
      Code{134217709, 27}
    case 252:
      Code{134217710, 27}
    case 253:
      Code{134217711, 27}
    case 254:
      Code{134217712, 27}
    case 255:
      Code{67108846, 26}
    case 256:
      Code{1073741823, 30}
    case _:
      Code{0, 0}

def width.of(c: Code) -> U32:
  match c:
    case Code{bits, width}:
      width

def width(+octet: U32) -> U32:
  width.of(code(octet))

def symbol(+width: U32, +bits: U32) -> Maybe<&2, U32>:
  match width:
    case 5:
      match bits:
        case 0:
          Some{48}
        case 1:
          Some{49}
        case 2:
          Some{50}
        case 3:
          Some{97}
        case 4:
          Some{99}
        case 5:
          Some{101}
        case 6:
          Some{105}
        case 7:
          Some{111}
        case 8:
          Some{115}
        case 9:
          Some{116}
        case _:
          None{}
    case 6:
      match bits:
        case 20:
          Some{32}
        case 21:
          Some{37}
        case 22:
          Some{45}
        case 23:
          Some{46}
        case 24:
          Some{47}
        case 25:
          Some{51}
        case 26:
          Some{52}
        case 27:
          Some{53}
        case 28:
          Some{54}
        case 29:
          Some{55}
        case 30:
          Some{56}
        case 31:
          Some{57}
        case 32:
          Some{61}
        case 33:
          Some{65}
        case 34:
          Some{95}
        case 35:
          Some{98}
        case 36:
          Some{100}
        case 37:
          Some{102}
        case 38:
          Some{103}
        case 39:
          Some{104}
        case 40:
          Some{108}
        case 41:
          Some{109}
        case 42:
          Some{110}
        case 43:
          Some{112}
        case 44:
          Some{114}
        case 45:
          Some{117}
        case _:
          None{}
    case 7:
      match bits:
        case 92:
          Some{58}
        case 93:
          Some{66}
        case 94:
          Some{67}
        case 95:
          Some{68}
        case 96:
          Some{69}
        case 97:
          Some{70}
        case 98:
          Some{71}
        case 99:
          Some{72}
        case 100:
          Some{73}
        case 101:
          Some{74}
        case 102:
          Some{75}
        case 103:
          Some{76}
        case 104:
          Some{77}
        case 105:
          Some{78}
        case 106:
          Some{79}
        case 107:
          Some{80}
        case 108:
          Some{81}
        case 109:
          Some{82}
        case 110:
          Some{83}
        case 111:
          Some{84}
        case 112:
          Some{85}
        case 113:
          Some{86}
        case 114:
          Some{87}
        case 115:
          Some{89}
        case 116:
          Some{106}
        case 117:
          Some{107}
        case 118:
          Some{113}
        case 119:
          Some{118}
        case 120:
          Some{119}
        case 121:
          Some{120}
        case 122:
          Some{121}
        case 123:
          Some{122}
        case _:
          None{}
    case 8:
      match bits:
        case 248:
          Some{38}
        case 249:
          Some{42}
        case 250:
          Some{44}
        case 251:
          Some{59}
        case 252:
          Some{88}
        case 253:
          Some{90}
        case _:
          None{}
    case 10:
      match bits:
        case 1016:
          Some{33}
        case 1017:
          Some{34}
        case 1018:
          Some{40}
        case 1019:
          Some{41}
        case 1020:
          Some{63}
        case _:
          None{}
    case 11:
      match bits:
        case 2042:
          Some{39}
        case 2043:
          Some{43}
        case 2044:
          Some{124}
        case _:
          None{}
    case 12:
      match bits:
        case 4090:
          Some{35}
        case 4091:
          Some{62}
        case _:
          None{}
    case 13:
      match bits:
        case 8184:
          Some{0}
        case 8185:
          Some{36}
        case 8186:
          Some{64}
        case 8187:
          Some{91}
        case 8188:
          Some{93}
        case 8189:
          Some{126}
        case _:
          None{}
    case 14:
      match bits:
        case 16380:
          Some{94}
        case 16381:
          Some{125}
        case _:
          None{}
    case 15:
      match bits:
        case 32764:
          Some{60}
        case 32765:
          Some{96}
        case 32766:
          Some{123}
        case _:
          None{}
    case 19:
      match bits:
        case 524272:
          Some{92}
        case 524273:
          Some{195}
        case 524274:
          Some{208}
        case _:
          None{}
    case 20:
      match bits:
        case 1048550:
          Some{128}
        case 1048551:
          Some{130}
        case 1048552:
          Some{131}
        case 1048553:
          Some{162}
        case 1048554:
          Some{184}
        case 1048555:
          Some{194}
        case 1048556:
          Some{224}
        case 1048557:
          Some{226}
        case _:
          None{}
    case 21:
      match bits:
        case 2097116:
          Some{153}
        case 2097117:
          Some{161}
        case 2097118:
          Some{167}
        case 2097119:
          Some{172}
        case 2097120:
          Some{176}
        case 2097121:
          Some{177}
        case 2097122:
          Some{179}
        case 2097123:
          Some{209}
        case 2097124:
          Some{216}
        case 2097125:
          Some{217}
        case 2097126:
          Some{227}
        case 2097127:
          Some{229}
        case 2097128:
          Some{230}
        case _:
          None{}
    case 22:
      match bits:
        case 4194258:
          Some{129}
        case 4194259:
          Some{132}
        case 4194260:
          Some{133}
        case 4194261:
          Some{134}
        case 4194262:
          Some{136}
        case 4194263:
          Some{146}
        case 4194264:
          Some{154}
        case 4194265:
          Some{156}
        case 4194266:
          Some{160}
        case 4194267:
          Some{163}
        case 4194268:
          Some{164}
        case 4194269:
          Some{169}
        case 4194270:
          Some{170}
        case 4194271:
          Some{173}
        case 4194272:
          Some{178}
        case 4194273:
          Some{181}
        case 4194274:
          Some{185}
        case 4194275:
          Some{186}
        case 4194276:
          Some{187}
        case 4194277:
          Some{189}
        case 4194278:
          Some{190}
        case 4194279:
          Some{196}
        case 4194280:
          Some{198}
        case 4194281:
          Some{228}
        case 4194282:
          Some{232}
        case 4194283:
          Some{233}
        case _:
          None{}
    case 23:
      match bits:
        case 8388568:
          Some{1}
        case 8388569:
          Some{135}
        case 8388570:
          Some{137}
        case 8388571:
          Some{138}
        case 8388572:
          Some{139}
        case 8388573:
          Some{140}
        case 8388574:
          Some{141}
        case 8388575:
          Some{143}
        case 8388576:
          Some{147}
        case 8388577:
          Some{149}
        case 8388578:
          Some{150}
        case 8388579:
          Some{151}
        case 8388580:
          Some{152}
        case 8388581:
          Some{155}
        case 8388582:
          Some{157}
        case 8388583:
          Some{158}
        case 8388584:
          Some{165}
        case 8388585:
          Some{166}
        case 8388586:
          Some{168}
        case 8388587:
          Some{174}
        case 8388588:
          Some{175}
        case 8388589:
          Some{180}
        case 8388590:
          Some{182}
        case 8388591:
          Some{183}
        case 8388592:
          Some{188}
        case 8388593:
          Some{191}
        case 8388594:
          Some{197}
        case 8388595:
          Some{231}
        case 8388596:
          Some{239}
        case _:
          None{}
    case 24:
      match bits:
        case 16777194:
          Some{9}
        case 16777195:
          Some{142}
        case 16777196:
          Some{144}
        case 16777197:
          Some{145}
        case 16777198:
          Some{148}
        case 16777199:
          Some{159}
        case 16777200:
          Some{171}
        case 16777201:
          Some{206}
        case 16777202:
          Some{215}
        case 16777203:
          Some{225}
        case 16777204:
          Some{236}
        case 16777205:
          Some{237}
        case _:
          None{}
    case 25:
      match bits:
        case 33554412:
          Some{199}
        case 33554413:
          Some{207}
        case 33554414:
          Some{234}
        case 33554415:
          Some{235}
        case _:
          None{}
    case 26:
      match bits:
        case 67108832:
          Some{192}
        case 67108833:
          Some{193}
        case 67108834:
          Some{200}
        case 67108835:
          Some{201}
        case 67108836:
          Some{202}
        case 67108837:
          Some{205}
        case 67108838:
          Some{210}
        case 67108839:
          Some{213}
        case 67108840:
          Some{218}
        case 67108841:
          Some{219}
        case 67108842:
          Some{238}
        case 67108843:
          Some{240}
        case 67108844:
          Some{242}
        case 67108845:
          Some{243}
        case 67108846:
          Some{255}
        case _:
          None{}
    case 27:
      match bits:
        case 134217694:
          Some{203}
        case 134217695:
          Some{204}
        case 134217696:
          Some{211}
        case 134217697:
          Some{212}
        case 134217698:
          Some{214}
        case 134217699:
          Some{221}
        case 134217700:
          Some{222}
        case 134217701:
          Some{223}
        case 134217702:
          Some{241}
        case 134217703:
          Some{244}
        case 134217704:
          Some{245}
        case 134217705:
          Some{246}
        case 134217706:
          Some{247}
        case 134217707:
          Some{248}
        case 134217708:
          Some{250}
        case 134217709:
          Some{251}
        case 134217710:
          Some{252}
        case 134217711:
          Some{253}
        case 134217712:
          Some{254}
        case _:
          None{}
    case 28:
      match bits:
        case 268435426:
          Some{2}
        case 268435427:
          Some{3}
        case 268435428:
          Some{4}
        case 268435429:
          Some{5}
        case 268435430:
          Some{6}
        case 268435431:
          Some{7}
        case 268435432:
          Some{8}
        case 268435433:
          Some{11}
        case 268435434:
          Some{12}
        case 268435435:
          Some{14}
        case 268435436:
          Some{15}
        case 268435437:
          Some{16}
        case 268435438:
          Some{17}
        case 268435439:
          Some{18}
        case 268435440:
          Some{19}
        case 268435441:
          Some{20}
        case 268435442:
          Some{21}
        case 268435443:
          Some{23}
        case 268435444:
          Some{24}
        case 268435445:
          Some{25}
        case 268435446:
          Some{26}
        case 268435447:
          Some{27}
        case 268435448:
          Some{28}
        case 268435449:
          Some{29}
        case 268435450:
          Some{30}
        case 268435451:
          Some{31}
        case 268435452:
          Some{127}
        case 268435453:
          Some{220}
        case 268435454:
          Some{249}
        case _:
          None{}
    case 30:
      match bits:
        case 1073741820:
          Some{10}
        case 1073741821:
          Some{13}
        case 1073741822:
          Some{22}
        case 1073741823:
          Some{256}
        case _:
          None{}
    case _:
      None{}

def size.valid(ok: Bool, +total: U32, +n: U32) -> Maybe<&2, U32>:
  match ok:
    case True{}:
      Some{(total + n : U32)}
    case False{}:
      None{}
def size.one(+octet: U32, +total: U32) -> Maybe<&2, U32>:
  +n = width(octet)
  size.valid(Bool.and(U32.is_ne(n, 0), U32.is_le(total, (4294967295 - n : U32))), total, n)


def size(s: String, +total: U32) -> Maybe<&2, U32>:
  match s:
    case SNil{}:
      Some{total}
    case SCon{Chr{c}, t}:
      do Maybe<&2, U32>:
        n: U32 <- size.one(c, total)
        size(t, n)

type Builder is Type:
  Builder{bytes: Bytes.Bytes, at: U32, partial: U32, bits: U32}

def emit.full(full: Bool, out: Bytes.Bytes, +at: U32, +partial: U32, +bits: U32) -> Builder:
  match full:
    case True{}:
      Builder{Bytes.set(out, at, partial), (at + 1 : U32), 0, 0}
    case False{}:
      Builder{out, at, partial, (bits + 1 : U32)}

def emit.bit(+bit: U32, st: Builder) -> Builder:
  Builder{out, +at, +partial, +bits} = st
  emit.full(U32.is_eq(bits, 7), out, at, ((partial << 1n) .|. bit : U32), bits)

def emit.bits(n: Nat, +code: U32, st: Builder) -> Builder:
  match n:
    case 0n:
      st
    case 1n+p:
      +p = p
      emit.bits(p, code, emit.bit(((code >> p) .&. 1 : U32), st))

def emit.code(c: Code, st: Builder) -> Builder:
  match c:
    case Code{bits, width}:
      emit.bits(U32.to_nat(width), bits, st)

def encode.go(s: String, st: Builder) -> Builder:
  match s:
    case SNil{}:
      st
    case SCon{Chr{c}, t}:
      encode.go(t, emit.code(code(c), st))

def encode.last(more: Bool, out: Bytes.Bytes, +at: U32, +partial: U32, +bits: U32) -> Bytes.Bytes:
  match more:
    case False{}:
      out
    case True{}:
      +pad = (8 - bits : U32)
      Bytes.set(out, at, ((partial << U32.to_nat(pad)) .|. ((1 << U32.to_nat(pad)) - 1 : U32) : U32))
def encode.finish(st: Builder) -> Bytes.Bytes:
  Builder{out, +at, +partial, +bits} = st
  encode.last(U32.is_ne(bits, 0), out, at, partial, bits)


def encode.ready(s: String, m: Maybe<&2, U32>) -> Maybe<&1, Bytes.Bytes>:
  match m:
    case None{}:
      None{}
    case Some{+bits}:
      +len = ((bits >> 3n) + Bool.pick(U32, U32.is_ne((bits .&. 7 : U32), 0), 1, 0) : U32)
      Some{encode.finish(encode.go(s, Builder{Bytes.new(len), 0, 0, 0}))}

# HPACK text is a byte string: code points above 255 are rejected.
def encode(+s: String) -> Maybe<&1, Bytes.Bytes>:
  encode.ready(s, size(s, 0))

type Decoder is Data:
  Decoder{bits: U32, width: U32, rev: String}

def decode.found(+octet: U32, rev: String) -> Maybe<&2, Decoder>:
  match octet:
    case 256:
      None{}
    case _:
      Some{Decoder{0, 0, SCon{Chr{octet}, rev}}}

def decode.pending(ok: Bool, +bits: U32, +width: U32, rev: String) -> Maybe<&2, Decoder>:
  match ok:
    case True{}:
      Some{Decoder{bits, width, rev}}
    case False{}:
      None{}
def decode.symbol(m: Maybe<&2, U32>, +bits: U32, +width: U32, rev: String) -> Maybe<&2, Decoder>:
  match m:
    case Some{octet}:
      decode.found(octet, rev)
    case None{}:
      decode.pending(U32.is_lt(width, 30), bits, width, rev)


def decode.bit(d: Decoder, +bit: U32) -> Maybe<&2, Decoder>:
  Decoder{+bits, +width, rev} = d
  +code = ((bits << 1n) .|. bit : U32)
  +n = (width + 1 : U32)
  decode.symbol(symbol(n, code), code, n, rev)

def decode.step(n: Nat, +byte: U32, d: Decoder) -> Maybe<&2, Decoder>:
  match n:
    case 0n:
      Some{d}
    case 1n+p:
      +p = p
      do Maybe<&2, Decoder>:
        next: Decoder <- decode.bit(d, ((byte >> p) .&. 1 : U32))
        decode.step(p, byte, next)

def with_number.got(-R: Type, m: Maybe<&2, U32>, b: Bytes.Bytes, k: Bytes.Bytes -> U32 -> R) -> R:
  match m:
    case Some{v}:
      k(b, v)
    case None{}:
      k(b, 0)
def with_number(-R: Type, r: Bytes.Bytes & Maybe<&2, U32>, k: Bytes.Bytes -> U32 -> R) -> R:
  (b, m) = r
  with_number.got(R, m, b, k)


def decode.go(n: Nat, b: Bytes.Bytes, +at: U32, d: Decoder) -> Maybe<&2, Decoder>:
  match n:
    case 0n:
      Some{d}
    case 1n+p:
      with_number(Maybe<&2, Decoder>, Bytes.get(b, at), b => byte =>
        do Maybe<&2, Decoder>:
          next: Decoder <- decode.step(8n, byte, d)
          decode.go(p, b, (at + 1 : U32), next))

def decode.tail(ok: Bool, rev: String) -> Maybe<&2, String>:
  match ok:
    case True{}:
      Some{String.reverse(rev)}
    case False{}:
      None{}

def decode.finish(m: Maybe<&2, Decoder>) -> Maybe<&2, String>:
  match m:
    case None{}:
      None{}
    case Some{Decoder{+bits, +width, rev}}:
      decode.tail(Bool.and(U32.is_le(width, 7), U32.is_eq(bits, ((1 << U32.to_nat(width)) - 1 : U32))), rev)

def decode(b: Bytes.Bytes) -> Maybe<&2, String>:
  Bytes.Bytes{+len, buf} = b
  decode.finish(decode.go(U32.to_nat(len), Bytes.Bytes{len, buf}, 0, Decoder{0, 0, SNil{}}))
