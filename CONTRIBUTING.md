# Contributing

Licensed under Apache-2.0. See [LICENSE](LICENSE) and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

The kit is in alpha. Breaking a public API is fine: change types, rename defs, and drop old entry points. Do not keep a compatibility shim. For a break, raise the second number of `<pkg>/VERSION` (`0.3.0.0` to `0.4.0.0`) and update siblings that import the package.

## A change

Work on a branch off `main` and open a pull request. Do not publish to the hub by hand. CI publishes a package that passes its checks.

A change to `<pkg>.bend` or `effs/` must raise `VERSION`. `scripts/publish.sh --check` fails a pull request that does not. A publish is permanent, so do not rename or move a published package's folder.

```sh
scripts/check.sh bytes http   # the packages you changed
```

`check.sh` type-checks the entry file, then runs `PROOF.bend` and `check.bend`. `bend PROOF.bend --check-only` prints `ALL PROOFS CHECK` when every law holds. A package with `effs/*.c` also needs `scripts/native-check.sh`: CI compiles `check.bend` and runs the binary.

`LAWS.bend` is the claims. Change a law only when the change in behavior is the point. `PROOF.bend` proves each law. Proofs do not cover `.c` and `.js` effects. An effect needs both twins.

A package whose public types come from a sibling imports that sibling from the hub, not by relative path. Package-local `LAWS.bend` and `check.bend` import the local file. A change to the sibling reaches the importer only after the sibling is published and the import version is raised. Publish dependencies first.

macOS or Linux, including WSL. Windows is not supported. CI installs the Bend version pinned in `scripts/install-bend.sh`.

Language rules that have bitten this repo, including affine use, quantities, and termination, are in [AGENTS.md](AGENTS.md).

## Bend bugs

Before calling something a compiler bug, reread `bend guide`, run `bend update`, and cut it down to the smallest file that still shows it. Search [bendlang/bend](https://github.com/bendlang/bend/issues) first. If an issue already covers it, comment the reproduction. Otherwise open one with the Bend version, OS, architecture, minimal file, command, and expected and actual output. Work around it here and comment the issue link next to the workaround.
