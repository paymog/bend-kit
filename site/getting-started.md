# Getting started

Use a published bend-kit package without cloning this repository.

## Install Bend

Use macOS or Linux, including WSL. Windows is not supported. Install Bend with the [official installer](https://bend-lang.com/install.sh):

```sh
curl -fsSL https://bend-lang.com/install.sh | sh
```

Open a new shell so that `bend` is on your path. Check the version:

```sh
bend version
```

This repository's CI uses Bend 2.0.40. Use that version or newer for this example. Install [Bun](https://bun.sh/docs/installation) if you use packages with JavaScript effects.

## Import a package

Save this program as `hello.bend`:

```bend
import Base
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes

def show(r: Bytes.Bytes & U32) -> IO(Unit):
  (b, n) = r
  IO.print(U32.show(n) ++ " " ++ Bytes.to_string(b))

def main() -> IO(Unit):
  show(Bytes.length(Bytes.from_string("hi")))
```

The import names a package, a four-part version, and a file. Bend fetches the package from the hub and checks its published hash. You do not need a package manager or a local copy of bend-kit.

## Check and run

Check the program without running it:

```sh
bend hello.bend --check-only
```

Then run it:

```sh
bend hello.bend
```

The program prints `2 hi`. To compile a native executable, run:

```sh
bend hello.bend -o hello && ./hello
```

## Choose more packages

The [package catalog](README.md) lists the available packages. Each package page includes its import, examples, laws, and limits. Start with the [Bytes page](bytes/README.md).

Use the dependency versions named in each package README when you pass values between packages. Different versions give distinct types. The kit is in alpha, so public APIs can change. Read the [changelog](CHANGELOG.md) for changes and the [roadmap](ROADMAP.md) for planned work.
