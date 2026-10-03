import Base
import ../contract.bend as Contract
import ./domain.bend as Domain

law publish_spec:
  for +owner: U32
  for +title: String
  for +secret: String
  for published: Bool
  {Domain.publish(Contract.Record{owner, title, secret, published}) == Contract.Record{owner, title, secret, True{}} : Contract.Record}

law view_spec:
  for +owner: U32
  for +title: String
  for secret: String
  for +published: Bool
  {Domain.view(Contract.Record{owner, title, secret, published}) == Contract.Public{owner, title, published} : Contract.Public}

law publish_idempotent:
  for +record: Contract.Record
  {Domain.publish(Domain.publish(record)) == Domain.publish(record) : Contract.Record}

law secret_noninterference:
  for +owner: U32
  for +title: String
  for +published: Bool
  for left: String
  for right: String
  {Domain.view(Contract.Record{owner, title, left, published}) == Domain.view(Contract.Record{owner, title, right, published}) : Contract.Public}
