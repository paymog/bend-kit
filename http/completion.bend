# Copied response completion data; successful host writes do not prove peer receipt.
import Base

type Outcome is Data:
  HostAccepted{}
  WriteFailed{code: U32, message: String}
  IncompleteResponse{}

type Completion<-D: Data> is Data:
  Completion{payload: D, status: U32, outcome: Outcome}

# Consumed inline while the admitted operation is still held.
# Supported receipts capture Data only through receipt's typed factory and a
# closed callback. Never hide affine dependencies in a disposable receipt.
type Receipt is Type:
  Unobserved{}
  Observed{send: U32 -> Outcome -> IO(Unit)}

def receipt.send(~D: Data, payload: D, +channel: Chan(Completion<D>), status: U32, outcome: Outcome) -> IO(Unit):
  do IO<Unit>:
    sent : Result<&1, &1, Completion<D>, Unit> <- Chan.send(Completion<D>, channel, Completion{payload, status, outcome})
    return Unit{}

def receipt(~D: Data, ~done: Completion<D> -> IO(Unit), payload: D) -> Receipt:
  Observed{status => outcome => done(Completion{payload, status, outcome})}

# The observer owns IO.join/explicit close, including when it receives later.
# Closing before reception is disposal; it never carries affine resources.
def open(~D: Data, payload: D) -> IO(Receipt & Chan(Completion<D>)):
  do IO<Receipt & Chan(Completion<D>)>:
    +channel : Chan(Completion<D>) <- Chan.new(Completion<D>, 1)
    return (Observed{status => outcome => receipt.send(~D, payload, channel, status, outcome)}, channel)

def report(receipt: Receipt, status: U32, outcome: Outcome) -> IO(Unit):
  match receipt:
    case Unobserved{}:
      IO.pure(Unit, Unit{})
    case Observed{send}:
      send(status, outcome)

# Explicit absence of a configured observer performs no logging or allocation.
def ignore(status: U32, outcome: Outcome) -> IO(Unit):
  IO.pure(Unit, Unit{})
