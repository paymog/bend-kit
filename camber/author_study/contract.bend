import Base

type Record is Data:
  Record{owner: U32, title: String, secret: String, published: Bool}

type Public is Data:
  Public{owner: U32, title: String, published: Bool}

type State is Type:
  State{journal: File, events: List<&2, String>}
