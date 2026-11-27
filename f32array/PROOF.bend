import Base
import ./f32array.bend as A
import ./LAWS.bend as Laws
import ./proofs.bend as P
import ./roundtrip-proof.bend as Roundtrip
import ./codec-model.bend as C
import ./endian-proof.bend as Endian

def Laws.new_zeros():
  {==}

def Laws.new_empty():
  {==}

def Laws.length_of():
  {==}

def Laws.list_roundtrip():
  {==}

def Laws.get_in():
  {==}

def Laws.get_past_len():
  {==}

def Laws.get_after_set(a, i, v, h):
  P.get_after_set(a, i, v, h)

def Laws.lane_after_put(c, k, v, h):
  P.lane_put(c, k, v, h)

def Laws.set_keeps_others():
  {==}

def Laws.set_past_len():
  {==}

def Laws.slice_middle():
  {==}

def Laws.slice_keeps_source():
  {==}

def Laws.slice_clamps_count():
  {==}

def Laws.slice_clamps_start():
  {==}

def Laws.concat_pieces():
  {==}

def Laws.concat_none():
  {==}

def Laws.map_each():
  {==}

def Laws.map_keeps_tail():
  {==}

def Laws.fold_order():
  {==}

def Laws.fold_empty():
  {==}

def Laws.zip_pairs():
  {==}

def Laws.zip_mismatch():
  {==}

def Laws.zip_gives_b_back():
  {==}

def Laws.add_mismatch():
  {==}

def Laws.mul_mismatch():
  {==}

def Laws.max_empty():
  {==}

def Laws.dot_mismatch():
  {==}

def Laws.to_bytes_le():
  {==}

def Laws.to_bytes_be():
  {==}

def Laws.from_bytes_le():
  {==}

def Laws.from_bytes_be():
  {==}

def Laws.from_bytes_unaligned():
  {==}

def Laws.from_bytes_empty():
  {==}

def Laws.bytes_roundtrip_le(a, h):
  Roundtrip.roundtrip(~A.to_bits, ~A.of_bits, ~A.from_bytes.le, ~C.from_bytes_le, ~C.bits_roundtrip, a, h)

def Laws.bytes_roundtrip_be(a, h):
  Roundtrip.roundtrip(~A.to_bits.be, ~A.of_bits.be, ~A.from_bytes.be, ~C.from_bytes_be, ~Endian.roundtrip, a, h)

def Laws.cells_roundtrip():
  {==}

def Laws.get_second_cell():
  {==}

def Laws.get_past_len_in_cell():
  {==}

def Laws.set_second_cell():
  {==}

def Laws.slice_aligned():
  {==}

def Laws.slice_across_cells():
  {==}

def Laws.slice_aligned_tail():
  {==}

def Laws.concat_cells():
  {==}

def Laws.map_cells():
  {==}

def Laws.fold_cells():
  {==}

def Laws.zip_cells():
  {==}

def Laws.zip_keeps_tail():
  {==}

def Laws.bytes_cells_le():
  {==}

def Laws.bytes_cells_be():
  {==}

def Laws.from_bytes_tail():
  {==}
