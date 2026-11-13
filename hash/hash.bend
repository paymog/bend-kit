# Non-cryptographic hashes over Bytes: FNV-1a, xxHash, SipHash-1-3, CRC-32, and Adler-32. Source: https://github.com/paymog/bend-kit/tree/main/hash
import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes

# Each hash hands the buffer back beside its value. A buffer's bytes at or past len are 0.
# Each hash also has a .str form over a byte string (one Char per octet), copied to Bytes first.
#   import bend-kit-hash@0.3.0.3/hash.bend as Hash

# A 64-bit value as two halves. Base has no native U64, and int's U64 is a bit list.
type W64 is Data:
  W64{hi: U32, lo: U32}

def W64.xor(a: W64, b: W64) -> W64:
  match a b:
    case W64{ah, al} W64{bh, bl}:
      W64{U32.xor(ah, bh), U32.xor(al, bl)}

def W64.add.of(+ah: U32, +bh: U32, +al: U32, +lo: U32) -> W64:
  W64{(ah + bh + Bool.pick(U32, U32.is_lt(lo, al), 1, 0) : U32), lo}

def W64.add(a: W64, b: W64) -> W64:
  match a b:
    case W64{+ah, +al} W64{+bh, +bl}:
      W64.add.of(ah, bh, al, (al + bl : U32))

# The full 64-bit product of two U32, from four 16-bit partial products.
def mul32.of(+p00: U32, +p01: U32, +p10: U32, +p11: U32) -> W64:
  +mid = ((p00 >> 16n) + (p01 .&. 65535) + (p10 .&. 65535) : U32)
  W64{(p11 + (p01 >> 16n) + (p10 >> 16n) + (mid >> 16n) : U32), ((p00 .&. 65535) .|. (mid << 16n) : U32)}

def mul32(+x: U32, +y: U32) -> W64:
  +x0 = (x .&. 65535 : U32)
  +x1 = (x >> 16n : U32)
  +y0 = (y .&. 65535 : U32)
  +y1 = (y >> 16n : U32)
  mul32.of((x0 * y0 : U32), (x0 * y1 : U32), (x1 * y0 : U32), (x1 * y1 : U32))

def W64.mul.of(+cross: U32, p: W64) -> W64:
  W64{+h, +l} = p
  W64{(h + cross : U32), l}

def W64.mul(a: W64, b: W64) -> W64:
  match a b:
    case W64{+ah, +al} W64{+bh, +bl}:
      W64.mul.of(((al * bh) + (ah * bl) : U32), mul32(al, bl))

# Rotate left by k, for 0 < k < 32; j is 32 - k.
def W64.rotl(+k: Nat, +j: Nat, a: W64) -> W64:
  match a:
    case W64{+h, +l}:
      W64{((h << k) .|. (l >> j) : U32), ((l << k) .|. (h >> j) : U32)}

def W64.swap(a: W64) -> W64:
  match a:
    case W64{h, l}:
      W64{l, h}

# Shift right by k, for 0 < k < 32; j is 32 - k.
def W64.shr(+k: Nat, +j: Nat, a: W64) -> W64:
  match a:
    case W64{+h, +l}:
      W64{(h >> k : U32), ((l >> k) .|. (h << j) : U32)}

def W64.lo(a: W64) -> U32:
  match a:
    case W64{h, l}:
      l

def rotl32(+x: U32, +k: Nat, +j: Nat) -> U32:
  ((x << k) .|. (x >> j) : U32)

# Folds f over n words from word i on. r holds the array and word i.
def wfold(~T: Type, ~f: T -> @+c: U32 -> T, n: Nat, r: Array<U32> & U32, +i: U32, acc: T) -> Array<U32> & T:
  match n:
    case 0n:
      (a, w) = r
      (a, acc)
    case 1n+p:
      (a, +w) = r
      +j = (i + 1 : U32)
      wfold(~T, ~f, p, Array.get(U32, a, j), j, f(acc, w))

def wfrom(~T: Type, ~f: T -> @+c: U32 -> T, n: Nat, a: Array<U32>, +i: U32, acc: T) -> Array<U32> & T:
  wfold(~T, ~f, n, Array.get(U32, a, i), i, acc)

# Words i and i + 1 as one little-endian 64-bit lane.
def get2.of(+lo: U32, r: Array<U32> & U32) -> Array<U32> & W64:
  (a, +hi) = r
  (a, W64{hi, lo})

def get2.lo(+i: U32, r: Array<U32> & U32) -> Array<U32> & W64:
  (a, +lo) = r
  get2.of(lo, Array.get(U32, a, (i + 1 : U32)))

def get2(a: Array<U32>, +i: U32) -> Array<U32> & W64:
  get2.lo(i, Array.get(U32, a, i))

# Folds f over n 64-bit lanes from word i on. r holds the array and the lane at i.
def dfold(~T: Type, ~f: T -> @+m: W64 -> T, n: Nat, r: Array<U32> & W64, +i: U32, acc: T) -> Array<U32> & T:
  match n:
    case 0n:
      (a, m) = r
      (a, acc)
    case 1n+p:
      (a, +m) = r
      +j = (i + 2 : U32)
      dfold(~T, ~f, p, get2(a, j), j, f(acc, m))

def dfrom(~T: Type, ~f: T -> @+m: W64 -> T, n: Nat, a: Array<U32>, +i: U32, acc: T) -> Array<U32> & T:
  dfold(~T, ~f, n, get2(a, i), i, acc)

# Folds f over the low k bytes of w, lowest first.
def tail(~T: Type, ~f: T -> @+c: U32 -> T, k: Nat, +w: U32, acc: T) -> T:
  match k:
    case 0n:
      acc
    case 1n+p:
      tail(~T, ~f, p, (w >> 8n : U32), f(acc, (w .&. 255 : U32)))

def bytewise.last(~T: Type, ~byte: T -> @+c: U32 -> T, +len: U32, acc: T, r: Array<U32> & U32) -> Bytes.Bytes & T:
  (a, +w) = r
  (Bytes.Bytes{len, a}, tail(~T, ~byte, U32.to_nat((len .&. 3 : U32)), w, acc))

def bytewise.rest(~T: Type, ~byte: T -> @+c: U32 -> T, +len: U32, r: Array<U32> & T) -> Bytes.Bytes & T:
  (a, acc) = r
  bytewise.last(~T, ~byte, len, acc, Array.get(U32, a, (len >> 2n : U32)))

# A hash that eats one byte at a time: word takes the four bytes of a word, byte one.
def bytewise(~T: Type, ~byte: T -> @+c: U32 -> T, ~word: T -> @+c: U32 -> T, b: Bytes.Bytes, acc: T) -> Bytes.Bytes & T:
  Bytes.Bytes{+len, buf} = b
  bytewise.rest(~T, ~byte, len, wfrom(~T, ~word, U32.to_nat((len >> 2n : U32)), buf, 0, acc))

# FNV-1a (draft-eastlake-fnv), 32 and 64 bits.
def fnv32.byte(h: U32, +c: U32) -> U32:
  ((h .^. c) * 16777619 : U32)

def fnv32.word(h: U32, +w: U32) -> U32:
  fnv32.byte(fnv32.byte(fnv32.byte(fnv32.byte(h, (w .&. 255 : U32)), ((w >> 8n) .&. 255 : U32)), ((w >> 16n) .&. 255 : U32)), (w >> 24n : U32))

def fnv1a32(b: Bytes.Bytes) -> Bytes.Bytes & U32:
  bytewise(~U32, ~fnv32.byte, ~fnv32.word, b, 2166136261)

def fnv64.byte(h: W64, +c: U32) -> W64:
  match h:
    case W64{hi, lo}:
      W64.mul(W64{hi, (lo .^. c : U32)}, W64{256, 435})

def fnv64.word(h: W64, +w: U32) -> W64:
  fnv64.byte(fnv64.byte(fnv64.byte(fnv64.byte(h, (w .&. 255 : U32)), ((w >> 8n) .&. 255 : U32)), ((w >> 16n) .&. 255 : U32)), (w >> 24n : U32))

def fnv1a64(b: Bytes.Bytes) -> Bytes.Bytes & W64:
  bytewise(~W64, ~fnv64.byte, ~fnv64.word, b, W64{3421674724, 2216829733})

# CRC-32 (ISO-HDLC, as in gzip and zlib): reflected, polynomial 0xEDB88320.
# The 256-entry table as a match, so no call rebuilds it.
def crc.tab(+i: U32) -> U32:
  match i:
    case 0: 0
    case 1: 1996959894
    case 2: 3993919788
    case 3: 2567524794
    case 4: 124634137
    case 5: 1886057615
    case 6: 3915621685
    case 7: 2657392035
    case 8: 249268274
    case 9: 2044508324
    case 10: 3772115230
    case 11: 2547177864
    case 12: 162941995
    case 13: 2125561021
    case 14: 3887607047
    case 15: 2428444049
    case 16: 498536548
    case 17: 1789927666
    case 18: 4089016648
    case 19: 2227061214
    case 20: 450548861
    case 21: 1843258603
    case 22: 4107580753
    case 23: 2211677639
    case 24: 325883990
    case 25: 1684777152
    case 26: 4251122042
    case 27: 2321926636
    case 28: 335633487
    case 29: 1661365465
    case 30: 4195302755
    case 31: 2366115317
    case 32: 997073096
    case 33: 1281953886
    case 34: 3579855332
    case 35: 2724688242
    case 36: 1006888145
    case 37: 1258607687
    case 38: 3524101629
    case 39: 2768942443
    case 40: 901097722
    case 41: 1119000684
    case 42: 3686517206
    case 43: 2898065728
    case 44: 853044451
    case 45: 1172266101
    case 46: 3705015759
    case 47: 2882616665
    case 48: 651767980
    case 49: 1373503546
    case 50: 3369554304
    case 51: 3218104598
    case 52: 565507253
    case 53: 1454621731
    case 54: 3485111705
    case 55: 3099436303
    case 56: 671266974
    case 57: 1594198024
    case 58: 3322730930
    case 59: 2970347812
    case 60: 795835527
    case 61: 1483230225
    case 62: 3244367275
    case 63: 3060149565
    case 64: 1994146192
    case 65: 31158534
    case 66: 2563907772
    case 67: 4023717930
    case 68: 1907459465
    case 69: 112637215
    case 70: 2680153253
    case 71: 3904427059
    case 72: 2013776290
    case 73: 251722036
    case 74: 2517215374
    case 75: 3775830040
    case 76: 2137656763
    case 77: 141376813
    case 78: 2439277719
    case 79: 3865271297
    case 80: 1802195444
    case 81: 476864866
    case 82: 2238001368
    case 83: 4066508878
    case 84: 1812370925
    case 85: 453092731
    case 86: 2181625025
    case 87: 4111451223
    case 88: 1706088902
    case 89: 314042704
    case 90: 2344532202
    case 91: 4240017532
    case 92: 1658658271
    case 93: 366619977
    case 94: 2362670323
    case 95: 4224994405
    case 96: 1303535960
    case 97: 984961486
    case 98: 2747007092
    case 99: 3569037538
    case 100: 1256170817
    case 101: 1037604311
    case 102: 2765210733
    case 103: 3554079995
    case 104: 1131014506
    case 105: 879679996
    case 106: 2909243462
    case 107: 3663771856
    case 108: 1141124467
    case 109: 855842277
    case 110: 2852801631
    case 111: 3708648649
    case 112: 1342533948
    case 113: 654459306
    case 114: 3188396048
    case 115: 3373015174
    case 116: 1466479909
    case 117: 544179635
    case 118: 3110523913
    case 119: 3462522015
    case 120: 1591671054
    case 121: 702138776
    case 122: 2966460450
    case 123: 3352799412
    case 124: 1504918807
    case 125: 783551873
    case 126: 3082640443
    case 127: 3233442989
    case 128: 3988292384
    case 129: 2596254646
    case 130: 62317068
    case 131: 1957810842
    case 132: 3939845945
    case 133: 2647816111
    case 134: 81470997
    case 135: 1943803523
    case 136: 3814918930
    case 137: 2489596804
    case 138: 225274430
    case 139: 2053790376
    case 140: 3826175755
    case 141: 2466906013
    case 142: 167816743
    case 143: 2097651377
    case 144: 4027552580
    case 145: 2265490386
    case 146: 503444072
    case 147: 1762050814
    case 148: 4150417245
    case 149: 2154129355
    case 150: 426522225
    case 151: 1852507879
    case 152: 4275313526
    case 153: 2312317920
    case 154: 282753626
    case 155: 1742555852
    case 156: 4189708143
    case 157: 2394877945
    case 158: 397917763
    case 159: 1622183637
    case 160: 3604390888
    case 161: 2714866558
    case 162: 953729732
    case 163: 1340076626
    case 164: 3518719985
    case 165: 2797360999
    case 166: 1068828381
    case 167: 1219638859
    case 168: 3624741850
    case 169: 2936675148
    case 170: 906185462
    case 171: 1090812512
    case 172: 3747672003
    case 173: 2825379669
    case 174: 829329135
    case 175: 1181335161
    case 176: 3412177804
    case 177: 3160834842
    case 178: 628085408
    case 179: 1382605366
    case 180: 3423369109
    case 181: 3138078467
    case 182: 570562233
    case 183: 1426400815
    case 184: 3317316542
    case 185: 2998733608
    case 186: 733239954
    case 187: 1555261956
    case 188: 3268935591
    case 189: 3050360625
    case 190: 752459403
    case 191: 1541320221
    case 192: 2607071920
    case 193: 3965973030
    case 194: 1969922972
    case 195: 40735498
    case 196: 2617837225
    case 197: 3943577151
    case 198: 1913087877
    case 199: 83908371
    case 200: 2512341634
    case 201: 3803740692
    case 202: 2075208622
    case 203: 213261112
    case 204: 2463272603
    case 205: 3855990285
    case 206: 2094854071
    case 207: 198958881
    case 208: 2262029012
    case 209: 4057260610
    case 210: 1759359992
    case 211: 534414190
    case 212: 2176718541
    case 213: 4139329115
    case 214: 1873836001
    case 215: 414664567
    case 216: 2282248934
    case 217: 4279200368
    case 218: 1711684554
    case 219: 285281116
    case 220: 2405801727
    case 221: 4167216745
    case 222: 1634467795
    case 223: 376229701
    case 224: 2685067896
    case 225: 3608007406
    case 226: 1308918612
    case 227: 956543938
    case 228: 2808555105
    case 229: 3495958263
    case 230: 1231636301
    case 231: 1047427035
    case 232: 2932959818
    case 233: 3654703836
    case 234: 1088359270
    case 235: 936918000
    case 236: 2847714899
    case 237: 3736837829
    case 238: 1202900863
    case 239: 817233897
    case 240: 3183342108
    case 241: 3401237130
    case 242: 1404277552
    case 243: 615818150
    case 244: 3134207493
    case 245: 3453421203
    case 246: 1423857449
    case 247: 601450431
    case 248: 3009837614
    case 249: 3294710456
    case 250: 1567103746
    case 251: 711928724
    case 252: 3020668471
    case 253: 3272380065
    case 254: 1510334235
    case _: 755167117

def crc.tab1(+i: U32) -> U32:
  match i:
    case 0: 0
    case 1: 421212481
    case 2: 842424962
    case 3: 724390851
    case 4: 1684849924
    case 5: 2105013317
    case 6: 1448781702
    case 7: 1329698503
    case 8: 3369699848
    case 9: 3519200073
    case 10: 4210026634
    case 11: 3824474571
    case 12: 2897563404
    case 13: 3048111693
    case 14: 2659397006
    case 15: 2274893007
    case 16: 1254232657
    case 17: 1406739216
    case 18: 2029285587
    case 19: 1643069842
    case 20: 783210325
    case 21: 934667796
    case 22: 479770071
    case 23: 92505238
    case 24: 2182846553
    case 25: 2600511768
    case 26: 2955803355
    case 27: 2838940570
    case 28: 3866582365
    case 29: 4285295644
    case 30: 3561045983
    case 31: 3445231262
    case 32: 2508465314
    case 33: 2359236067
    case 34: 2813478432
    case 35: 3198777185
    case 36: 4058571174
    case 37: 3908292839
    case 38: 3286139684
    case 39: 3670389349
    case 40: 1566420650
    case 41: 1145479147
    case 42: 1869335592
    case 43: 1987116393
    case 44: 959540142
    case 45: 539646703
    case 46: 185010476
    case 47: 303839341
    case 48: 3745920755
    case 49: 3327985586
    case 50: 3983561841
    case 51: 4100678960
    case 52: 3140154359
    case 53: 2721170102
    case 54: 2300350837
    case 55: 2416418868
    case 56: 396344571
    case 57: 243568058
    case 58: 631889529
    case 59: 1018359608
    case 60: 1945336319
    case 61: 1793607870
    case 62: 1103436669
    case 63: 1490954812
    case 64: 4034481925
    case 65: 3915546180
    case 66: 3259968903
    case 67: 3679722694
    case 68: 2484439553
    case 69: 2366552896
    case 70: 2787371139
    case 71: 3208174018
    case 72: 950060301
    case 73: 565965900
    case 74: 177645455
    case 75: 328046286
    case 76: 1556873225
    case 77: 1171730760
    case 78: 1861902987
    case 79: 2011255754
    case 80: 3132841300
    case 81: 2745199637
    case 82: 2290958294
    case 83: 2442530455
    case 84: 3738671184
    case 85: 3352078609
    case 86: 3974232786
    case 87: 4126854035
    case 88: 1919080284
    case 89: 1803150877
    case 90: 1079293406
    case 91: 1498383519
    case 92: 370020952
    case 93: 253043481
    case 94: 607678682
    case 95: 1025720731
    case 96: 1711106983
    case 97: 2095471334
    case 98: 1472923941
    case 99: 1322268772
    case 100: 26324643
    case 101: 411738082
    case 102: 866634785
    case 103: 717028704
    case 104: 2904875439
    case 105: 3024081134
    case 106: 2668790573
    case 107: 2248782444
    case 108: 3376948395
    case 109: 3495106026
    case 110: 4219356713
    case 111: 3798300520
    case 112: 792689142
    case 113: 908347575
    case 114: 487136116
    case 115: 68299317
    case 116: 1263779058
    case 117: 1380486579
    case 118: 2036719216
    case 119: 1618931505
    case 120: 3890672638
    case 121: 4278043327
    case 122: 3587215740
    case 123: 3435896893
    case 124: 2206873338
    case 125: 2593195963
    case 126: 2981909624
    case 127: 2829542713
    case 128: 998479947
    case 129: 580430090
    case 130: 162921161
    case 131: 279890824
    case 132: 1609522511
    case 133: 1190423566
    case 134: 1842954189
    case 135: 1958874764
    case 136: 4082766403
    case 137: 3930137346
    case 138: 3245109441
    case 139: 3631694208
    case 140: 2536953671
    case 141: 2385372678
    case 142: 2768287173
    case 143: 3155920004
    case 144: 1900120602
    case 145: 1750776667
    case 146: 1131931800
    case 147: 1517083097
    case 148: 355290910
    case 149: 204897887
    case 150: 656092572
    case 151: 1040194781
    case 152: 3113746450
    case 153: 2692952403
    case 154: 2343461520
    case 155: 2461357009
    case 156: 3723805974
    case 157: 3304059991
    case 158: 4022511508
    case 159: 4141455061
    case 160: 2919742697
    case 161: 3072101800
    case 162: 2620513899
    case 163: 2234183466
    case 164: 3396041197
    case 165: 3547351212
    case 166: 4166851439
    case 167: 3779471918
    case 168: 1725839073
    case 169: 2143618976
    case 170: 1424512099
    case 171: 1307796770
    case 172: 45282277
    case 173: 464110244
    case 174: 813994343
    case 175: 698327078
    case 176: 3838160568
    case 177: 4259225593
    case 178: 3606301754
    case 179: 3488152955
    case 180: 2158586812
    case 181: 2578602749
    case 182: 2996767038
    case 183: 2877569151
    case 184: 740041904
    case 185: 889656817
    case 186: 506086962
    case 187: 120682355
    case 188: 1215357364
    case 189: 1366020341
    case 190: 2051441462
    case 191: 1667084919
    case 192: 3422213966
    case 193: 3538019855
    case 194: 4190942668
    case 195: 3772220557
    case 196: 2945847882
    case 197: 3062702859
    case 198: 2644537544
    case 199: 2226864521
    case 200: 52649286
    case 201: 439905287
    case 202: 823476164
    case 203: 672009861
    case 204: 1733269570
    case 205: 2119477507
    case 206: 1434057408
    case 207: 1281543041
    case 208: 2167981343
    case 209: 2552493150
    case 210: 3004082077
    case 211: 2853541596
    case 212: 3847487515
    case 213: 4233048410
    case 214: 3613549209
    case 215: 3464057816
    case 216: 1239502615
    case 217: 1358593622
    case 218: 2077699477
    case 219: 1657543892
    case 220: 764250643
    case 221: 882293586
    case 222: 532408465
    case 223: 111204816
    case 224: 1585378284
    case 225: 1197851309
    case 226: 1816695150
    case 227: 1968414767
    case 228: 974272232
    case 229: 587794345
    case 230: 136598634
    case 231: 289367339
    case 232: 2527558116
    case 233: 2411481253
    case 234: 2760973158
    case 235: 3179948583
    case 236: 4073438432
    case 237: 3956313505
    case 238: 3237863010
    case 239: 3655790371
    case 240: 347922877
    case 241: 229101820
    case 242: 646611775
    case 243: 1066513022
    case 244: 1892689081
    case 245: 1774917112
    case 246: 1122387515
    case 247: 1543337850
    case 248: 3697634229
    case 249: 3313392372
    case 250: 3998419255
    case 251: 4148705398
    case 252: 3087642289
    case 253: 2702352368
    case 254: 2319436851
    case _: 2468674930

def crc.tab2(+i: U32) -> U32:
  match i:
    case 0: 0
    case 1: 29518391
    case 2: 59036782
    case 3: 38190681
    case 4: 118073564
    case 5: 114017003
    case 6: 76381362
    case 7: 89069189
    case 8: 236147128
    case 9: 265370511
    case 10: 228034006
    case 11: 206958561
    case 12: 152762724
    case 13: 148411219
    case 14: 178138378
    case 15: 190596925
    case 16: 472294256
    case 17: 501532999
    case 18: 530741022
    case 19: 509615401
    case 20: 456068012
    case 21: 451764635
    case 22: 413917122
    case 23: 426358261
    case 24: 305525448
    case 25: 334993663
    case 26: 296822438
    case 27: 275991697
    case 28: 356276756
    case 29: 352202787
    case 30: 381193850
    case 31: 393929805
    case 32: 944588512
    case 33: 965684439
    case 34: 1003065998
    case 35: 973863097
    case 36: 1061482044
    case 37: 1049003019
    case 38: 1019230802
    case 39: 1023561829
    case 40: 912136024
    case 41: 933002607
    case 42: 903529270
    case 43: 874031361
    case 44: 827834244
    case 45: 815125939
    case 46: 852716522
    case 47: 856752605
    case 48: 611050896
    case 49: 631869351
    case 50: 669987326
    case 51: 640506825
    case 52: 593644876
    case 53: 580921211
    case 54: 551983394
    case 55: 556069653
    case 56: 712553512
    case 57: 733666847
    case 58: 704405574
    case 59: 675154545
    case 60: 762387700
    case 61: 749958851
    case 62: 787859610
    case 63: 792175277
    case 64: 1889177024
    case 65: 1901651959
    case 66: 1931368878
    case 67: 1927033753
    case 68: 2006131996
    case 69: 1985040171
    case 70: 1947726194
    case 71: 1976933189
    case 72: 2122964088
    case 73: 2135668303
    case 74: 2098006038
    case 75: 2093965857
    case 76: 2038461604
    case 77: 2017599123
    case 78: 2047123658
    case 79: 2076625661
    case 80: 1824272048
    case 81: 1836991623
    case 82: 1866005214
    case 83: 1861914857
    case 84: 1807058540
    case 85: 1786244187
    case 86: 1748062722
    case 87: 1777547317
    case 88: 1655668488
    case 89: 1668093247
    case 90: 1630251878
    case 91: 1625932113
    case 92: 1705433044
    case 93: 1684323811
    case 94: 1713505210
    case 95: 1742760333
    case 96: 1222101792
    case 97: 1226154263
    case 98: 1263738702
    case 99: 1251046777
    case 100: 1339974652
    case 101: 1310460363
    case 102: 1281013650
    case 103: 1301863845
    case 104: 1187289752
    case 105: 1191637167
    case 106: 1161842422
    case 107: 1149379777
    case 108: 1103966788
    case 109: 1074747507
    case 110: 1112139306
    case 111: 1133218845
    case 112: 1425107024
    case 113: 1429406311
    case 114: 1467333694
    case 115: 1454888457
    case 116: 1408811148
    case 117: 1379576507
    case 118: 1350309090
    case 119: 1371438805
    case 120: 1524775400
    case 121: 1528845279
    case 122: 1499917702
    case 123: 1487177649
    case 124: 1575719220
    case 125: 1546255107
    case 126: 1584350554
    case 127: 1605185389
    case 128: 3778354048
    case 129: 3774312887
    case 130: 3803303918
    case 131: 3816007129
    case 132: 3862737756
    case 133: 3892238699
    case 134: 3854067506
    case 135: 3833203973
    case 136: 4012263992
    case 137: 4007927823
    case 138: 3970080342
    case 139: 3982554209
    case 140: 3895452388
    case 141: 3924658387
    case 142: 3953866378
    case 143: 3932773565
    case 144: 4245928176
    case 145: 4241609415
    case 146: 4271336606
    case 147: 4283762345
    case 148: 4196012076
    case 149: 4225268251
    case 150: 4187931714
    case 151: 4166823541
    case 152: 4076923208
    case 153: 4072833919
    case 154: 4035198246
    case 155: 4047918865
    case 156: 4094247316
    case 157: 4123732899
    case 158: 4153251322
    case 159: 4132437965
    case 160: 3648544096
    case 161: 3636082519
    case 162: 3673983246
    case 163: 3678331705
    case 164: 3732010428
    case 165: 3753090955
    case 166: 3723829714
    case 167: 3694611429
    case 168: 3614117080
    case 169: 3601426159
    case 170: 3572488374
    case 171: 3576541825
    case 172: 3496125444
    case 173: 3516976691
    case 174: 3555094634
    case 175: 3525581405
    case 176: 3311336976
    case 177: 3298595879
    case 178: 3336186494
    case 179: 3340255305
    case 180: 3260503756
    case 181: 3281337595
    case 182: 3251864226
    case 183: 3222399125
    case 184: 3410866088
    case 185: 3398419871
    case 186: 3368647622
    case 187: 3372945905
    case 188: 3427010420
    case 189: 3448139075
    case 190: 3485520666
    case 191: 3456284973
    case 192: 2444203584
    case 193: 2423127159
    case 194: 2452308526
    case 195: 2481530905
    case 196: 2527477404
    case 197: 2539934891
    case 198: 2502093554
    case 199: 2497740997
    case 200: 2679949304
    case 201: 2659102159
    case 202: 2620920726
    case 203: 2650438049
    case 204: 2562027300
    case 205: 2574714131
    case 206: 2603727690
    case 207: 2599670141
    case 208: 2374579504
    case 209: 2353749767
    case 210: 2383274334
    case 211: 2412743529
    case 212: 2323684844
    case 213: 2336421851
    case 214: 2298759554
    case 215: 2294686645
    case 216: 2207933576
    case 217: 2186809023
    case 218: 2149495014
    case 219: 2178734801
    case 220: 2224278612
    case 221: 2236720739
    case 222: 2266437690
    case 223: 2262135309
    case 224: 2850214048
    case 225: 2820717207
    case 226: 2858812622
    case 227: 2879680249
    case 228: 2934667388
    case 229: 2938704459
    case 230: 2909776914
    case 231: 2897069605
    case 232: 2817622296
    case 233: 2788420399
    case 234: 2759153014
    case 235: 2780249921
    case 236: 2700618180
    case 237: 2704950259
    case 238: 2742877610
    case 239: 2730399645
    case 240: 3049550800
    case 241: 3020298727
    case 242: 3057690558
    case 243: 3078802825
    case 244: 2999835404
    case 245: 3004150075
    case 246: 2974355298
    case 247: 2961925461
    case 248: 3151438440
    case 249: 3121956959
    case 250: 3092510214
    case 251: 3113327665
    case 252: 3168701108
    case 253: 3172786307
    case 254: 3210370778
    case _: 3197646061

def crc.tab3(+i: U32) -> U32:
  match i:
    case 0: 0
    case 1: 3099354981
    case 2: 2852767883
    case 3: 313896942
    case 4: 2405603159
    case 5: 937357362
    case 6: 627793884
    case 7: 2648127673
    case 8: 3316918511
    case 9: 2097696650
    case 10: 1874714724
    case 11: 3607201537
    case 12: 1255587768
    case 13: 4067088605
    case 14: 3772741427
    case 15: 1482887254
    case 16: 1343838111
    case 17: 3903140090
    case 18: 4195393300
    case 19: 1118632049
    case 20: 3749429448
    case 21: 1741137837
    case 22: 1970407491
    case 23: 3452858150
    case 24: 2511175536
    case 25: 756094997
    case 26: 1067759611
    case 27: 2266550430
    case 28: 449832999
    case 29: 2725482306
    case 30: 2965774508
    case 31: 142231497
    case 32: 2687676222
    case 33: 412010587
    case 34: 171665333
    case 35: 2995192016
    case 36: 793786473
    case 37: 2548850444
    case 38: 2237264098
    case 39: 1038456711
    case 40: 1703315409
    case 41: 3711623348
    case 42: 3482275674
    case 43: 1999841343
    case 44: 3940814982
    case 45: 1381529571
    case 46: 1089329165
    case 47: 4166106984
    case 48: 4029413537
    case 49: 1217896388
    case 50: 1512189994
    case 51: 3802027855
    case 52: 2135519222
    case 53: 3354724499
    case 54: 3577784189
    case 55: 1845280792
    case 56: 899665998
    case 57: 2367928107
    case 58: 2677414085
    case 59: 657096608
    case 60: 3137160985
    case 61: 37822588
    case 62: 284462994
    case 63: 2823350519
    case 64: 2601801789
    case 65: 598228824
    case 66: 824021174
    case 67: 2309093331
    case 68: 343330666
    case 69: 2898962447
    case 70: 3195996129
    case 71: 113467524
    case 72: 1587572946
    case 73: 3860600759
    case 74: 4104763481
    case 75: 1276501820
    case 76: 3519211397
    case 77: 1769898208
    case 78: 2076913422
    case 79: 3279374443
    case 80: 3406630818
    case 81: 1941006535
    case 82: 1627703081
    case 83: 3652755532
    case 84: 1148164341
    case 85: 4241751952
    case 86: 3999682686
    case 87: 1457141531
    case 88: 247015245
    case 89: 3053797416
    case 90: 2763059142
    case 91: 470583459
    case 92: 2178658330
    case 93: 963106687
    case 94: 735213713
    case 95: 2473467892
    case 96: 992409347
    case 97: 2207944806
    case 98: 2435792776
    case 99: 697522413
    case 100: 3024379988
    case 101: 217581361
    case 102: 508405983
    case 103: 2800865210
    case 104: 4271038444
    case 105: 1177467017
    case 106: 1419450215
    case 107: 3962007554
    case 108: 1911572667
    case 109: 3377213406
    case 110: 3690561584
    case 111: 1665525589
    case 112: 1799331996
    case 113: 3548628985
    case 114: 3241568279
    case 115: 2039091058
    case 116: 3831314379
    case 117: 1558270126
    case 118: 1314193216
    case 119: 4142438437
    case 120: 2928380019
    case 121: 372764438
    case 122: 75645176
    case 123: 3158189981
    case 124: 568925988
    case 125: 2572515393
    case 126: 2346768303
    case 127: 861712586
    case 128: 3982079547
    case 129: 1441124702
    case 130: 1196457648
    case 131: 4293663189
    case 132: 1648042348
    case 133: 3666298377
    case 134: 3358779879
    case 135: 1888390786
    case 136: 686661332
    case 137: 2421291441
    case 138: 2196002399
    case 139: 978858298
    case 140: 2811169155
    case 141: 523464422
    case 142: 226935048
    case 143: 3040519789
    case 144: 3175145892
    case 145: 100435649
    case 146: 390670639
    case 147: 2952089162
    case 148: 841119475
    case 149: 2325614998
    case 150: 2553003640
    case 151: 546822429
    case 152: 2029308235
    case 153: 3225988654
    case 154: 3539796416
    case 155: 1782671013
    case 156: 4153826844
    case 157: 1328167289
    case 158: 1570739863
    case 159: 3844338162
    case 160: 1298864389
    case 161: 4124540512
    case 162: 3882013070
    case 163: 1608431339
    case 164: 3255406162
    case 165: 2058742071
    case 166: 1744848601
    case 167: 3501990332
    case 168: 2296328682
    case 169: 811816591
    case 170: 584513889
    case 171: 2590678532
    case 172: 129869501
    case 173: 3204563416
    case 174: 2914283062
    case 175: 352848211
    case 176: 494030490
    case 177: 2781751807
    case 178: 3078325777
    case 179: 264757620
    case 180: 2450577869
    case 181: 715964072
    case 182: 941166918
    case 183: 2158327331
    case 184: 3636881013
    case 185: 1618608400
    case 186: 1926213374
    case 187: 3396585883
    case 188: 1470427426
    case 189: 4011365959
    case 190: 4255988137
    case 191: 1158766284
    case 192: 1984818694
    case 193: 3471935843
    case 194: 3695453837
    case 195: 1693991400
    case 196: 4180638033
    case 197: 1100160564
    case 198: 1395044826
    case 199: 3952793279
    case 200: 3019491049
    case 201: 189112716
    case 202: 435162722
    case 203: 2706139399
    case 204: 1016811966
    case 205: 2217162459
    case 206: 2526189877
    case 207: 774831696
    case 208: 643086745
    case 209: 2666061564
    case 210: 2354934034
    case 211: 887166583
    case 212: 2838900430
    case 213: 294275499
    case 214: 54519365
    case 215: 3145957664
    case 216: 3823145334
    case 217: 1532818963
    case 218: 1240029693
    case 219: 4048895640
    case 220: 1820460577
    case 221: 3560857924
    case 222: 3331051178
    case 223: 2117577167
    case 224: 3598663992
    case 225: 1858283101
    case 226: 2088143283
    case 227: 3301633750
    case 228: 1495127663
    case 229: 3785470218
    case 230: 4078182116
    case 231: 1269332353
    case 232: 332098007
    case 233: 2876706482
    case 234: 3116540252
    case 235: 25085497
    case 236: 2628386432
    case 237: 605395429
    case 238: 916469259
    case 239: 2384220526
    case 240: 2254837415
    case 241: 1054503362
    case 242: 745528876
    case 243: 2496903497
    case 244: 151290352
    case 245: 2981684885
    case 246: 2735556987
    case 247: 464596510
    case 248: 1137851976
    case 249: 4218313005
    case 250: 3923506883
    case 251: 1365741990
    case 252: 3434129695
    case 253: 1946996346
    case 254: 1723425172
    case _: 3724871409

def crc.byte(h: U32, +c: U32) -> U32:
  +x = h
  (crc.tab(((x .^. c) .&. 255 : U32)) .^. (x >> 8n) : U32)

def crc.word(h: U32, +w: U32) -> U32:
  +x = (h .^. w : U32)
  (((crc.tab3((x .&. 255 : U32)) .^. crc.tab2(((x >> 8n) .&. 255 : U32))) .^. crc.tab1(((x >> 16n) .&. 255 : U32))) .^. crc.tab((x >> 24n : U32)) : U32)

def crc.fin(r: Bytes.Bytes & U32) -> Bytes.Bytes & U32:
  (b, +h) = r
  (b, (h .^. 4294967295 : U32))

def crc32(b: Bytes.Bytes) -> Bytes.Bytes & U32:
  crc.fin(bytewise(~U32, ~crc.byte, ~crc.word, b, 4294967295))

# Adler-32 (RFC 1950 §9). The state is the checksum itself: s2 << 16 | s1.
# A word takes mod 65521 once, after four bytes; no sum reaches 2^32 first.
def adler.of(+s1: U32, +s2: U32) -> U32:
  (((s2 % 65521) << 16n) .|. (s1 % 65521) : U32)

def adler.byte(h0: U32, +c: U32) -> U32:
  +h = h0
  +s1 = ((h .&. 65535) + c : U32)
  adler.of(s1, ((h >> 16n) + s1 : U32))

def adler.word(h0: U32, +w: U32) -> U32:
  +h = h0
  +a0 = ((h .&. 65535) + (w .&. 255) : U32)
  +a1 = (a0 + ((w >> 8n) .&. 255) : U32)
  +a2 = (a1 + ((w >> 16n) .&. 255) : U32)
  +a3 = (a2 + (w >> 24n) : U32)
  adler.of(a3, ((h >> 16n) + a0 + a1 + a2 + a3 : U32))

def adler32(b: Bytes.Bytes) -> Bytes.Bytes & U32:
  bytewise(~U32, ~adler.byte, ~adler.word, b, 1)

# xxHash32 (XXH32, xxHash spec 0.1.1).
type V4 is Data:
  V4{a: U32, b: U32, c: U32, d: U32}

def x32.round(+acc: U32, +x: U32) -> U32:
  (rotl32((acc + x * 2246822519 : U32), 13n, 19n) * 2654435761 : U32)

# The four accumulators take lanes in turn: v1 eats this word and moves to the back.
def x32.lane(v: V4, +w: U32) -> V4:
  match v:
    case V4{a, b, c, d}:
      V4{b, c, d, x32.round(a, w)}

def x32.merge(r: Array<U32> & V4) -> Array<U32> & U32:
  (buf, V4{+a, +b, +c, +d}) = r
  (buf, (rotl32(a, 1n, 31n) + rotl32(b, 7n, 25n) + rotl32(c, 12n, 20n) + rotl32(d, 18n, 14n) : U32))

def x32.word(h: U32, +w: U32) -> U32:
  (rotl32((h + w * 3266489917 : U32), 17n, 15n) * 668265263 : U32)

def x32.byte(h: U32, +c: U32) -> U32:
  (rotl32((h + c * 374761393 : U32), 11n, 21n) * 2654435761 : U32)

def x32.aval.c(+h: U32) -> U32:
  (h .^. (h >> 16n) : U32)

def x32.aval.b(+h: U32) -> U32:
  x32.aval.c(((h .^. (h >> 13n)) * 3266489917 : U32))

def x32.aval(+h: U32) -> U32:
  x32.aval.b(((h .^. (h >> 15n)) * 2246822519 : U32))

def x32.tail(+len: U32, +h: U32, r: Array<U32> & U32) -> Bytes.Bytes & U32:
  (a, +w) = r
  (Bytes.Bytes{len, a}, x32.aval(tail(~U32, ~x32.byte, U32.to_nat((len .&. 3 : U32)), w, h)))

def x32.rest(+len: U32, r: Array<U32> & U32) -> Bytes.Bytes & U32:
  (a, +h) = r
  x32.tail(len, h, Array.get(U32, a, (len >> 2n : U32)))

def x32.mid(+len: U32, r: Array<U32> & U32) -> Bytes.Bytes & U32:
  (a, +h) = r
  x32.rest(len, wfrom(~U32, ~x32.word, U32.to_nat(((len .&. 15) >> 2n : U32)), a, ((len >> 4n) << 2n : U32), (h + len : U32)))

def x32.start(big: Bool, +len: U32, +seed: U32, a: Array<U32>) -> Array<U32> & U32:
  match big:
    case True{}:
      x32.merge(wfrom(~V4, ~x32.lane, U32.to_nat(((len >> 4n) << 2n : U32)), a, 0, V4{(seed + 606290984 : U32), (seed + 2246822519 : U32), seed, (seed + 1640531535 : U32)}))
    case False{}:
      (a, (seed + 374761393 : U32))

def xxh32(b: Bytes.Bytes, +seed: U32) -> Bytes.Bytes & U32:
  Bytes.Bytes{+len, buf} = b
  x32.mid(len, x32.start(U32.is_le(16, len), len, seed, buf))

# xxHash64 (XXH64, xxHash spec 0.1.1).
type V64 is Data:
  V64{a: W64, b: W64, c: W64, d: W64}

def x64.P1() -> W64:
  W64{2654435761, 2246822535}

def x64.P2() -> W64:
  W64{3266489917, 668265295}

def x64.P3() -> W64:
  W64{374761393, 2654435833}

def x64.P4() -> W64:
  W64{2246822519, 3266489955}

def x64.P5() -> W64:
  W64{668265263, 374761413}

def x64.round(acc: W64, x: W64) -> W64:
  W64.mul(W64.rotl(31n, 1n, W64.add(acc, W64.mul(x, x64.P2()))), x64.P1())

def x64.lane(v: V64, +m: W64) -> V64:
  match v:
    case V64{a, b, c, d}:
      V64{b, c, d, x64.round(a, m)}

def x64.fold(h: W64, v: W64) -> W64:
  W64.add(W64.mul(W64.xor(h, x64.round(W64{0, 0}, v)), x64.P1()), x64.P4())

def x64.merge(r: Array<U32> & V64) -> Array<U32> & W64:
  (buf, V64{+a, +b, +c, +d}) = r
  +h = W64.add(W64.add(W64.rotl(1n, 31n, a), W64.rotl(7n, 25n, b)), W64.add(W64.rotl(12n, 20n, c), W64.rotl(18n, 14n, d)))
  (buf, x64.fold(x64.fold(x64.fold(x64.fold(h, a), b), c), d))

def x64.word(h: W64, +m: W64) -> W64:
  W64.add(W64.mul(W64.rotl(27n, 5n, W64.xor(h, x64.round(W64{0, 0}, m))), x64.P1()), x64.P4())

def x64.byte(h: W64, +c: U32) -> W64:
  W64.mul(W64.rotl(11n, 21n, W64.xor(h, W64.mul(W64{0, c}, x64.P5()))), x64.P1())

def x64.four(h: W64, +w: U32) -> W64:
  W64.add(W64.mul(W64.rotl(23n, 9n, W64.xor(h, W64.mul(W64{0, w}, x64.P1()))), x64.P2()), x64.P3())

def x64.aval.c(h: W64) -> W64:
  match h:
    case W64{+hi, lo}:
      W64{hi, (lo .^. hi : U32)}

def x64.aval.b(+h: W64) -> W64:
  x64.aval.c(W64.mul(W64.xor(h, W64.shr(29n, 3n, h)), x64.P3()))

def x64.aval(h: W64) -> W64:
  match h:
    case W64{+hi, lo}:
      x64.aval.b(W64.mul(W64{hi, (lo .^. (hi >> 1n) : U32)}, x64.P2()))

# The last len % 8 bytes: a 4-byte lane when there is one, then single bytes.
def x64.bytes(four: Bool, +k: Nat, h: W64, m: W64) -> W64:
  match four:
    case True{}:
      match m:
        case W64{+hi, +lo}:
          tail(~W64, ~x64.byte, k, hi, x64.four(h, lo))
    case False{}:
      match m:
        case W64{hi, +lo}:
          tail(~W64, ~x64.byte, k, lo, h)

def x64.tail(+len: U32, +h: W64, r: Array<U32> & W64) -> Bytes.Bytes & W64:
  (a, m) = r
  (Bytes.Bytes{len, a}, x64.aval(x64.bytes(U32.is_ne((len .&. 4 : U32), 0), U32.to_nat((len .&. 3 : U32)), h, m)))

def x64.rest(+len: U32, r: Array<U32> & W64) -> Bytes.Bytes & W64:
  (a, h) = r
  x64.tail(len, h, get2(a, ((len >> 3n) << 1n : U32)))

def x64.mid(+len: U32, r: Array<U32> & W64) -> Bytes.Bytes & W64:
  (a, h) = r
  x64.rest(len, dfrom(~W64, ~x64.word, U32.to_nat(((len .&. 31) >> 3n : U32)), a, ((len >> 5n) << 3n : U32), W64.add(h, W64{0, len})))

def x64.start(big: Bool, +len: U32, +seed: W64, a: Array<U32>) -> Array<U32> & W64:
  match big:
    case True{}:
      x64.merge(dfrom(~V64, ~x64.lane, U32.to_nat(((len >> 5n) << 2n : U32)), a, 0, V64{W64.add(seed, W64{1625958382, 2915087830}), W64.add(seed, x64.P2()), seed, W64.add(seed, W64{1640531534, 2048144761})}))
    case False{}:
      (a, W64.add(seed, x64.P5()))

def xxh64(b: Bytes.Bytes, +seed: W64) -> Bytes.Bytes & W64:
  Bytes.Bytes{+len, buf} = b
  x64.mid(len, x64.start(U32.is_le(32, len), len, seed, buf))

# SipHash-1-3 (Aumasson and Bernstein, 2012): one round per block, three to finish.
type S4 is Data:
  S4{v0: W64, v1: W64, v2: W64, v3: W64}

def sip.round(s: S4) -> S4:
  S4{v0, +v1, v2, +v3} = s
  +a0 = W64.add(v0, v1)
  +b1 = W64.xor(W64.rotl(13n, 19n, v1), a0)
  +a2 = W64.add(v2, v3)
  +b3 = W64.xor(W64.rotl(16n, 16n, v3), a2)
  +c0 = W64.add(W64.swap(a0), b3)
  +c2 = W64.add(a2, b1)
  S4{c0, W64.xor(W64.rotl(17n, 15n, b1), c2), W64.swap(c2), W64.xor(W64.rotl(21n, 11n, b3), c0)}

def sip.post(+m: W64, s: S4) -> S4:
  S4{v0, v1, v2, v3} = s
  S4{W64.xor(v0, m), v1, v2, v3}

def sip.block(s: S4, +m: W64) -> S4:
  S4{v0, v1, v2, v3} = s
  sip.post(m, sip.round(S4{v0, v1, v2, W64.xor(v3, m)}))

def sip.fin(s: S4) -> W64:
  S4{v0, v1, v2, v3} = s
  W64.xor(W64.xor(v0, v1), W64.xor(v2, v3))

def sip.end(s: S4) -> W64:
  S4{v0, v1, v2, v3} = s
  sip.fin(sip.round(sip.round(sip.round(S4{v0, v1, W64.xor(v2, W64{0, 255}), v3}))))

# The low n bytes of w, for n <= 4, so bytes past len never reach the hash.
def sip.keep(+w: U32, +n: U32) -> U32:
  Bool.pick(U32, U32.is_lt(n, 4), (w .&. (U32.shln(1, U32.to_nat((n * 8 : U32))) - 1) : U32), w)

# The last block: the len % 8 bytes left, and len mod 256 in the top byte.
def sip.last(+len: U32, r: Array<U32> & W64, s: S4) -> Bytes.Bytes & W64:
  (a, W64{+hi, +lo}) = r
  +k = (len .&. 7 : U32)
  +top = ((len .&. 255) << 24n : U32)
  (Bytes.Bytes{len, a}, sip.end(sip.block(s, W64{(sip.keep(hi, Bool.pick(U32, U32.is_lt(4, k), (k - 4 : U32), 0)) .|. top : U32), sip.keep(lo, U32.min(k, 4))})))

def sip.rest(+len: U32, r: Array<U32> & S4) -> Bytes.Bytes & W64:
  (a, s) = r
  sip.last(len, get2(a, ((len >> 3n) << 1n : U32)), s)

def siphash13(b: Bytes.Bytes, +k0: W64, +k1: W64) -> Bytes.Bytes & W64:
  Bytes.Bytes{+len, buf} = b
  sip.rest(len, dfrom(~S4, ~sip.block, U32.to_nat((len >> 3n : U32)), buf, 0, S4{W64.xor(k0, W64{1936682341, 1886610805}), W64.xor(k1, W64{1685025377, 1852075885}), W64.xor(k0, W64{1819895653, 1852142177}), W64.xor(k1, W64{1952801890, 2037671283})}))

# The same hashes over a byte string. ponytail: copies to Bytes; hash short strings in place if the copy shows up in profiles.
def v32(r: Bytes.Bytes & U32) -> U32:
  (b, h) = r
  h

def v64(r: Bytes.Bytes & W64) -> W64:
  (b, h) = r
  h

def fnv1a32.str(+s: String) -> U32:
  v32(fnv1a32(Bytes.from_string(s)))

def fnv1a64.str(+s: String) -> W64:
  v64(fnv1a64(Bytes.from_string(s)))

def xxh32.str(+s: String, +seed: U32) -> U32:
  v32(xxh32(Bytes.from_string(s), seed))

def xxh64.str(+s: String, +seed: W64) -> W64:
  v64(xxh64(Bytes.from_string(s), seed))

def siphash13.str(+s: String, +k0: W64, +k1: W64) -> W64:
  v64(siphash13(Bytes.from_string(s), k0, k1))

def crc32.str(+s: String) -> U32:
  v32(crc32(Bytes.from_string(s)))

def adler32.str(+s: String) -> U32:
  v32(adler32(Bytes.from_string(s)))
