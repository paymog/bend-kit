# Application-only or actual transport completion, with a closed safe access projection.
import Base
import bend-kit-time@0.1.2.1/time.bend as Time
import bend-kit-int@0.2.0.0/int.bend as Int
import bend-kit-http@0.32.0.0/completion.bend as Transport
import bend-kit-notch@0.1.0.1/notch.bend as Notch

type Outcome is Data:
  ApplicationOnly{}
  Transport{outcome: Transport.Outcome}

type Notice is Data:
  Notice{status: U32, duration: Time.Duration, mapped: Bool, stopped: Bool, outcome: Outcome}

# No caller-supplied logger context or request fields can enter an access line.
type Access is Data:
  Disabled{}
  Enabled{format: Notch.Format}

def outcome.name(outcome: Outcome) -> String:
  match outcome:
    case ApplicationOnly{}: "application_only"
    case Transport{Transport.HostAccepted{}}: "host_accepted"
    case Transport{Transport.WriteFailed{code, message}}: "write_failed"
    case Transport{Transport.IncompleteResponse{}}: "incomplete_response"

def access(config: Access, notice: Notice) -> IO(Unit):
  match config:
    case Disabled{}: IO.pure(Unit, Unit{})
    case Enabled{format}:
      Notice{status, duration, mapped, stopped, outcome} = notice
      Notch.info(Notch.Logger{Notch.Info{}, format, Nil{}}, "access",
        [Notch.num("status", status), Notch.str("duration_ms", Int.I64.show(Time.Duration.to_ms(duration))),
         Notch.flag("mapped", mapped), Notch.flag("stopped", stopped), Notch.str("outcome", outcome.name(outcome))])
