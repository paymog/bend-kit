# Native erasure slowdown reproduction: https://github.com/bendlang/bend/issues/1307
import Base

type Blob is Type:
  Blob{size: U32, buffer: Array<U32>}

type Item is Type:
  Item{blob: Blob}

def build(count: Nat, acc: List<&1, Item>) -> List<&1, Item>:
  match count:
    case 0n:
      acc
    case 1n+rest:
      build(rest, Item{Blob{1, Array.new(U32, 0n, 48)}} <> acc)

def elapsed(label: String, start: Nat) -> IO(Unit):
  do IO<Unit>:
    end : Nat <- IO.now()
    IO.print(label ++ " " ++ Nat.show((end - start : Nat)))

def erased(value: List<&1, Item>, start: Nat) -> IO(Unit):
  elapsed("DISPOSE_MS", start)

def retained(value: List<&1, Item>, +output: Chan(List<&1, Item>), start: Nat) -> IO(Unit):
  do IO<Unit>:
    sent : Result<&1, &1, List<&1, Item>, Unit> <- Chan.send(List<&1, Item>, output, value)
    elapsed("BUILD_MS", start)
    disposal : Nat <- IO.now()
    received : List<&1, Item> <- IO.join(List<&1, Item>, output)
    erased(received, disposal)

def measure(nodes: Nat) -> IO(Unit):
  do IO<Unit>:
    output0 : Chan(List<&1, Item>) <- Chan.new(List<&1, Item>, 1)
    +output : Chan(List<&1, Item>) = output0
    start : Nat <- IO.now()
    retained(build(nodes, Nil{}), output, start)

def repeat(count: Nat, +nodes: Nat) -> IO(Unit):
  match count:
    case 0n:
      IO.print("DONE")
    case 1n+rest:
      do IO<Unit>:
        measure(nodes)
        repeat(rest, nodes)

def main() -> IO(Unit):
  repeat(24n, U32.to_nat(524283))
