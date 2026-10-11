# bend-kit

A general-purpose library for Bend 2, one hub package per folder. Bend is new, so your priors about it are weak or wrong. Run `bend guide` before you write Bend code. It is the full language guide for the installed compiler. Where the two disagree, the checker is right. `bend base Map` prints one Base name and everything under it. `bend base --types` prints the Base types. CI runs the Bend version pinned in `scripts/install-bend.sh`, which can be older than your local `bend`.

## Bend in brief

Bend looks like Python but acts like Haskell or Lean, with Rust-style resource rules.

- **Pure, with IO.** Effects live in `IO(T)` and run in `do IO<T>:` blocks. Every bind has a type: `x : T <- m`. `return v` wraps a pure value.
- **Affine by default.** A variable is used at most once. `+x` lets you use it more than once, but only when its type is `Data` (copyable). `-x` is erased: types and proofs only. `type T is Data:` is copyable; `type T is Type:` is not. Closures, arrays, and handles (`Socket`, `File`) are `Type`, so every effect on a handle gives the handle back beside its result.
- **Quantities in types.** `&0`, `&1`, `&2` say how often values of a type may be used. You see them everywhere here: `Maybe<&2, String>`, `Map<&2, List<&2, String>>`, `Result<&1, &1, U32 & String, Socket>`. `A & B` is a pair type; `(a, b)` is a pair value.
- **Little inference.** Every operator expression needs a type: `(n - 16 : U32)`, `(t1 - t0 : Nat)`. Inside `( : T)`, operators call `T.add` and so on. Every argument is explicit: `_` is not a hole the checker fills. `==` is only the equality type. For a value test, call `U32.is_eq(a, b)` or `String.eq(a, b)`.
- **No `if`.** Match on `True{}` / `False{}`, or use `Bool.pick(T, cond, a, b)`. `Bool.pick` evaluates both branches.
- **`match` takes only a parameter or a pattern-bound variable.** A computed value cannot be the scrutinee, and `(a, b) = f(x)` counts as a match. Pass the value to a helper that matches on its parameter, as in `drop_cr` → `drop_cr.if`. Match parameters in the order they are declared: to match a `Bool` flag before destructuring an earlier parameter, put the flag first. A binder used whole in one arm cannot be destructured in another arm; destructure it in every arm, or pass it to a helper. Dots in names are only characters.
- **Define before use.** A def can call only defs above it in the file (or imported), so helpers go first.
- **Termination is checked.** Each recursive call must pass a structurally smaller piece of its input, and the checker reads arguments left to right, so put the shrinking parameter first. Mutual recursion is not allowed. Merge the functions into one def with a selector argument. For loops bounded by the outside world, count down a `Nat` fuel argument. `@unsafe` skips the check and loses the proof guarantees, so write a terminating def instead.
- **Templates for generic code.** Pass a comparator or other function as a template, `~cmp: K -> K -> Cmp`, as in `List.sort`. A template can be called many times; a closure only once. A template cannot call a law that is filled below it, so it cannot use Base's pattern of declaring a `law`, calling it from a helper, and filling it later. To branch on `cmp(k, key)` inside a recursive template, pass each branch as a `Unit -> A` closure to a helper, as `Cmp.case` does in `collections/omap.bend`. Compiled `Array` code needs its element type as a template (`~T`), not erased (`-T`).
- **Literals.** `42` is `U32`, `3n` is `Nat`, `'c'` is `Char`, `"s"` is `String`. A `Nat` literal stops at `4294967295n`. A `String` is a list of `Char`: `SCon{Chr{c}, t}` / `SNil{}`. Lists are `Con{h, t}` / `Nil{}`, and `[a, b]` or `h <> t`.
- **Modules.** `import ./url/url.bend as Url` makes `Url.x` name each def in that file. A hub package imports by name, `import bend-kit-bytes@<version>/bytes.bend as Bytes`, or by content hash, `import 0x<hash>/bytes.bend as Bytes`. Both give the same types.

## Bend bugs

Bend is young, so the compiler, checker, runtime, or guide can be wrong. Before you call something a bug, rule out your own misreading: reread `bend guide`, run `bend update`, and cut the problem down to the smallest file that still shows it. Report a genuine bug at [bendlang/bend](https://github.com/bendlang/bend/issues).

1. Search open and closed issues first: `gh issue list -R bendlang/bend --state all --search "<keywords>"`. Try a few phrasings, including the error text. If an issue already covers it, add your reproduction as a comment rather than opening a new one.
2. Otherwise open one with `gh issue create -R bendlang/bend`. Include the Bend version (`bend version`), the OS and architecture, the minimal file, the command you ran, and the expected and actual output.
3. Work around the bug in this repo, and put a comment next to the workaround that links the issue, so it can be removed once the fix ships.

A checker stack overflow ("the machine stack overflowed") is a known limit that the maintainers close without a fix (bendlang/bend#1071). Work around it and link that issue; open a new issue only for a different failure.

## Memory

A native `bend` run can grow without bound. On 2026-09-24, three `bend` processes (about 56 GB together) filled this 48 GB Mac and the kernel panicked. Check a small input first. Run one `bend` process at a time. If one passes about 20 GB RSS, kill it. Start one only when the data volume has free space for swap.

## Laws and proofs

A law is a claim; a proof is a def with the same name. Each package has:

- `LAWS.bend`: the claims, each `law name:`. The human owns this file. Change a law only when the user asks.
- `PROOF.bend`: imports `LAWS.bend` and proves each law as `def Laws.name(...)`. Most laws here are concrete fixtures, so the proof is `{==}` (both sides compute to the same term).
- `bend PROOF.bend --check-only` is the gate. It prints `ALL PROOFS CHECK` when every law holds. An open or false law prints `SOME PROOFS FAIL`.
- A universal law over a comparator takes the comparator and its order facts as templates (`for ~cmp`, `for ~trans: ...`), so the proof can use each fact many times. The checker checks a template def once, against opaque arguments, so lemmas can be plain template defs. `collections/PROOF.bend` shows the patterns, such as `split` for a goal that branches on a comparison.
- Take `Nat`, `List`, and `Bool` lemmas from `bend-mathlib@0.7.2.0` (`nat.bend`, `list.bend`, `bool.bend`). Put a lemma that mathlib lacks in `lemmas/lemmas.bend`.
- `U32` arithmetic does not reduce by `{==}`: `(x + 0 : U32)` does not compute to `x`. State a claim about `U32` values over `U32.to_nat`, and use the `u32_` laws in `lemmas/lemmas.bend`, such as `u32_add_nat`, `u32_sub_nat`, `u32_cmp_nat`, and `u32_fits_nat`. Write `2^32` as `Lemmas.pow2(32n)`, and keep it folded (see `lemmas/README.md`).

## Repo facts

- Prefer `Bytes.Bytes` to `String` for octets, big inputs, and hot paths: codecs, parsers of bodies, socket and process IO. A `String` is a linked list with one cell per `Char`, so walking and freeing it is slow; the `bytes` bench measured `Array` 9–270× faster. Keep `String` for code points (`unicode`) and short text such as header fields, paths, and URLs. At an effect boundary, use the packed `(len, Array<U32>)` form, as `wire`'s `.words` effects do, not an octet `String`. HTTP bodies are `Http.Body`, which is `Bytes.Bytes`.
- Foreign effects are defs whose body is `import "./effs/<pkg>.c"` plus `import "./effs/<pkg>.js"`, as in `wire/wire.bend`. Every effect needs both twins, and the host function name is the def name, lowercased, with dots as underscores. Read `bend guide effects` before you write one. Proofs do not cover host code.
- **Pure or native.** Call a C library through an effect for crypto, heavy sequential byte work (compression, codecs), and OS services; pure Bend is about 100× slower than C on byte loops. Write pure Bend when pure code must call it (an effect returns `IO`), and for parsers and protocol logic, where the laws are the value. Load the library with `dlopen` and a `BEND_LIB<NAME>` override, and make the JS twin `bun:ffi` on the same library, as `wire/effs` does for libssl.
- `bend file.bend` runs through the checker's runner and overflows on strings over about 30 KB. Build big-body programs natively: `bend file.bend -o app`.
- [README.md](README.md#layout) lists the files of a package. `scripts/packages.sh` finds packages by their entry file `<pkg>/<pkg>.bend`, so a new package needs no CI change. `scripts/check.sh [pkg...]` is the type and proof gate. CI also runs `scripts/native-check.sh` for a package with `effs/*.c`: compile `check.bend` and run the binary, one Bend process per job. CI checks only the packages a PR changes. `bend <file> --check-only` is a fast type check.
- The hub shows the first comment line of a package's entry file as its description. Keep it one accurate line. It links to `tree/main/<pkg>`, and a publish is permanent, so keep a published package's folder name and place.
- Packages publish to the Bend hub as `bend-kit-<package>@<version>`, with the version in `<pkg>/VERSION`. CI publishes on merge to `main` with `scripts/publish.sh`; publish only through CI. The hub rejects a republish, so a change to a published file (`<pkg>.bend`, its imports, or `effs/`) must raise `VERSION`; `scripts/publish.sh --check` fails a PR that does not. Names are 12 to 64 characters of `a-z`, `0-9`, and `-`, and versions have four numbers.
- The kit is in alpha. Breaking a public API is fine when a better design needs it: change types, rename defs, and drop old entry points. Migrate every caller in the same change, with no compatibility shim or second path. For a break, raise the second number of `VERSION` (0.3.0.0 to 0.4.0.0), and update the siblings that import the package.
- A package whose public types come from a sibling imports that sibling from the hub (by name, or by hash until the hub names it), so its types match the ones callers import. A change to the sibling reaches it only after the sibling publishes and the import version rises, so publish dependencies first. Package-local `LAWS.bend`, `PROOF.bend`, and `check.bend` import local files by relative path.
- The hub registers at most five new names per account per day. `bend link <name>@<version> 0x<hash>` names a package that is already published.

## Benchmarks

A package is not done until its `bench/` runs. The bench times the package's hot path on one fixed input, in Bend and in C, Rust, Python, and JavaScript.

- Compare against each language's standard library, or against a very popular library when the standard library has no equivalent (`httparse` in Rust, `llhttp` in C, `h11` in Python). When neither gives an easy way to do the work, leave that language out and say so in the README.
- Use the obvious loop in each language. Glue, such as slicing a body after a head-only parser, is fine; a reimplementation of the package in another language is not.
- `bench/README.md` records the command, the input, the language versions, and the times. Every program prints a checksum, and the checksums agree.
- A package with no runtime hot path, such as `lemmas`, says so in `bench/README.md` instead.
- Run a bench by hand. `scripts/check.sh` and CI do not run it.

## Delivery

- Finish coding work with a pull request. Commit and push the branch, then open a PR before reporting the work done.

## GitHub issues

- Express every dependency between issues as a native GitHub "blocked by" link, not only as text in the body. After `gh issue create`, add each link: `gh api -X POST repos/paymog/bend-kit/issues/<N>/dependencies/blocked_by -F issue_id=$(gh api repos/paymog/bend-kit/issues/<blocker> --jq .id)`. The `issue_id` is the blocker's database id, not its number.
- When you file a follow-up, check whether it blocks or is blocked by an open issue, and add those links too.
