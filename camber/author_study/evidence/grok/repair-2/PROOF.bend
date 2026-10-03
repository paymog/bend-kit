import Base
import ../contract.bend as Contract
import ./LAWS.bend as Laws

def Laws.publish_spec(owner, title, secret, published):
  {==}

def Laws.view_spec(owner, title, secret, published):
  {==}

def Laws.publish_idempotent(record):
  match record:
    case Contract.Record{owner, title, secret, published}:
      {==}

def Laws.secret_noninterference(owner, title, published, left, right):
  {==}
