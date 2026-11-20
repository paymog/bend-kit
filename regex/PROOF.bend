import Base
import ./regex.bend as R
import ./LAWS.bend as Laws

def Laws.literal():
  {==}

def Laws.no_match():
  {==}

def Laws.empty_pattern():
  {==}

def Laws.leftmost_first():
  {==}

def Laws.leftmost_start():
  {==}

def Laws.greedy_star():
  {==}

def Laws.lazy_star():
  {==}

def Laws.lazy_plus():
  {==}

def Laws.quest():
  {==}

def Laws.count_exact():
  {==}

def Laws.count_range():
  {==}

def Laws.count_open():
  {==}

def Laws.count_lazy():
  {==}

def Laws.brace_literal():
  {==}

def Laws.captures():
  {==}

def Laws.capture_unset():
  {==}

def Laws.capture_last_iteration():
  {==}

def Laws.capture_nested():
  {==}

def Laws.capture_alternatives():
  {==}

def Laws.noncapturing():
  {==}

def Laws.empty_loop():
  {==}

def Laws.anchor_start():
  {==}

def Laws.anchor_end():
  {==}

def Laws.anchor_text():
  {==}

def Laws.word_boundary():
  {==}

def Laws.not_word_boundary():
  {==}

def Laws.dot_no_newline():
  {==}

def Laws.escape_meta():
  {==}

def Laws.class_range():
  {==}

def Laws.class_negated():
  {==}

def Laws.class_bracket_dash():
  {==}

def Laws.perl_digit():
  {==}

def Laws.perl_word():
  {==}

def Laws.perl_in_class():
  {==}

def Laws.unicode_letter():
  {==}

def Laws.unicode_short():
  {==}

def Laws.unicode_negated():
  {==}

def Laws.unicode_in_class():
  {==}

def Laws.pathological():
  {==}

def Laws.pathological_hit():
  {==}

def Laws.is_match_hit():
  {==}

def Laws.is_match_miss():
  {==}

def Laws.literal_prefix():
  {==}

def Laws.literal_prefix_end():
  {==}

def Laws.negated_start():
  {==}

def Laws.empty_start():
  {==}

def Laws.bits_hit():
  {==}

def Laws.bits_miss():
  {==}

def Laws.bits_start():
  {==}

def Laws.bits_start_hit():
  {==}

def Laws.bits_end():
  {==}

def Laws.bits_end_miss():
  {==}

def Laws.bits_empty_text():
  {==}

def Laws.bits_empty_at_end():
  {==}

def Laws.bits_text_anchors():
  {==}

def Laws.bits_start_inside():
  {==}

def Laws.bits_loop():
  {==}

def Laws.bits_loop_miss():
  {==}

def Laws.bits_pathological():
  {==}

def Laws.bits_negated():
  {==}

def Laws.bits_unicode():
  {==}

def Laws.bits_word_boundary():
  {==}

def Laws.bits_large():
  {==}

def Laws.bytes_literal():
  {==}

def Laws.bytes_no_match():
  {==}

def Laws.bytes_utf8_offsets():
  {==}

def Laws.bytes_unicode_class():
  {==}

def Laws.bytes_dot_multibyte():
  {==}

def Laws.bytes_four_byte():
  {==}

def Laws.bytes_invalid():
  {==}

def Laws.bytes_truncated():
  {==}

def Laws.bytes_overlong():
  {==}

def Laws.bytes_captures():
  {==}

def Laws.bytes_leftmost_first():
  {==}

def Laws.bytes_literal_prefix():
  {==}

def Laws.bytes_skip_multibyte():
  {==}

def Laws.bytes_empty_start():
  {==}

def Laws.bytes_empty_text():
  {==}

def Laws.bytes_anchor_end():
  {==}

def Laws.bytes_word_boundary():
  {==}

def Laws.bytes_pathological():
  {==}

def Laws.bytes_bits_hit():
  {==}

def Laws.bytes_bits_miss():
  {==}

def Laws.bytes_bits_start():
  {==}

def Laws.bytes_bits_empty_at_end():
  {==}

def Laws.bytes_bits_empty_text():
  {==}

def Laws.bytes_bits_skip_miss():
  {==}

def Laws.bytes_bits_skip_hit():
  {==}

def Laws.bytes_bits_utf8():
  {==}

def Laws.bytes_bits_skip_multibyte():
  {==}

def Laws.bytes_bits_word_boundary():
  {==}

def Laws.dfa_captures_replay():
  {==}

def Laws.dfa_capture_alternatives():
  {==}

def Laws.dfa_capture_last_iteration():
  {==}

def Laws.dfa_capture_unset():
  {==}

def Laws.dfa_email():
  {==}

def Laws.dfa_lazy():
  {==}

def Laws.dfa_leftmost_first():
  {==}

def Laws.dfa_anchored():
  {==}

def Laws.dfa_anchored_miss():
  {==}

def Laws.dfa_empty_loop():
  {==}

def Laws.dfa_pathological_hit():
  {==}

def Laws.dfa_nested():
  {==}

def Laws.dfa_cache_full():
  {==}

def Laws.required_absent():
  {==}

def Laws.required_overlap():
  {==}

def Laws.required_repeated():
  {==}

def Laws.required_optional():
  {==}

def Laws.required_positive():
  {==}

def Laws.required_candidates():
  {==}

def Laws.required_alternatives():
  {==}

def Laws.required_priority():
  {==}


def Laws.required_non_ascii():
  {==}

def Laws.required_dense():
  {==}



def Laws.dfa_non_ascii():
  {==}

def Laws.dfa_same_run():
  {==}

def Laws.dfa_same_non_ascii():
  {==}

def Laws.dfa_same_last_byte():
  {==}

def Laws.dfa_spin_run():
  {==}

def Laws.dfa_spin_non_ascii():
  {==}

def Laws.dfa_spin_last_byte():
  {==}

def Laws.dfa_any_large_hit():
  {==}

def Laws.dfa_any_large_miss():
  {==}

def Laws.bad_unclosed():
  {==}

def Laws.bad_close():
  {==}

def Laws.bad_repeat_nothing():
  {==}

def Laws.bad_repeat_repeat():
  {==}

def Laws.bad_class():
  {==}

def Laws.bad_range():
  {==}

def Laws.bad_escape():
  {==}

def Laws.bad_trailing_escape():
  {==}

def Laws.bad_property():
  {==}

def Laws.bad_count():
  {==}

def Laws.bad_count_order():
  {==}

def Laws.bad_flags():
  {==}

def Laws.flag_leading():
  {==}

def Laws.bad_flag_inside():
  {==}

def Laws.bad_flag_group():
  {==}

def Laws.bad_flag_twice():
  {==}

def Laws.fold_literal():
  {==}

def Laws.fold_off_by_default():
  {==}

def Laws.fold_empty():
  {==}

def Laws.fold_class_range():
  {==}

def Laws.fold_class_range_non_ascii():
  {==}

def Laws.fold_negated_class():
  {==}

def Laws.fold_negated_class_non_ascii():
  {==}

def Laws.fold_word():
  {==}

def Laws.word_no_fold():
  {==}

def Laws.fold_not_word():
  {==}

def Laws.fold_not_word_in_class():
  {==}

def Laws.fold_digit():
  {==}

def Laws.fold_upper():
  {==}

def Laws.fold_not_upper():
  {==}

def Laws.fold_kelvin():
  {==}

def Laws.fold_long_s():
  {==}

def Laws.fold_sigma():
  {==}

def Laws.fold_accent():
  {==}

def Laws.fold_simple_only():
  {==}

def Laws.fold_sharp_s():
  {==}

def Laws.fold_captures():
  {==}

def Laws.fold_word_boundary():
  {==}

def Laws.fold_bytes_kelvin():
  {==}

def Laws.fold_bytes_literal():
  {==}

def Laws.fold_bytes_not_word():
  {==}

def Laws.fold_bits():
  {==}

def Laws.fold_bits_not_word():
  {==}

def Laws.fold_bits_bytes():
  {==}

def Laws.lead_boundary():
  {==}

def Laws.lead_boundary_bytes():
  {==}

def Laws.lead_boundary_after_wide():
  {==}

def Laws.lead_boundary_after_wide_bytes():
  {==}

def Laws.lead_not_boundary():
  {==}

def Laws.lead_not_boundary_bytes():
  {==}

def Laws.lead_start():
  {==}

def Laws.lead_start_bytes():
  {==}

def Laws.lead_digits():
  {==}

def Laws.lead_digits_bytes():
  {==}

def Laws.lead_fold_boundary():
  {==}

def Laws.lead_fold_boundary_bytes():
  {==}

def Laws.dfa_full():
  {==}

def Laws.dfa_full_bytes():
  {==}

def Laws.dfa_full_none():
  {==}

def Laws.dfa_full_none_bytes():
  {==}

def Laws.dfa_idle_prev():
  {==}

def Laws.dfa_idle_prev_bytes():
  {==}

def Laws.dfa_wide():
  {==}

def Laws.dfa_wide_bytes():
  {==}

def Laws.dfa_wide_lit():
  {==}

def Laws.dfa_wide_lit_bytes():
  {==}

def Laws.dfa_groups():
  {==}

def Laws.dfa_groups_bytes():
  {==}

def Laws.dfa_end():
  {==}

def Laws.dfa_end_bytes():
  {==}

def Laws.dfa_empty_text():
  {==}

def Laws.dfa_empty_text_bytes():
  {==}

def Laws.dfa_fold_wide():
  {==}

def Laws.dfa_fold_wide_bytes():
  {==}

def Laws.dfa_hit_boundary():
  {==}

def Laws.dfa_hit_boundary_bytes():
  {==}

def Laws.dfa_miss_boundary():
  {==}

def Laws.dfa_miss_boundary_bytes():
  {==}

def Laws.need_absent():
  {==}

def Laws.need_absent_bytes():
  {==}

def Laws.need_absent_hit():
  {==}

def Laws.need_absent_hit_bytes():
  {==}

def Laws.need_no_match():
  {==}

def Laws.need_no_match_bytes():
  {==}

def Laws.need_late():
  {==}

def Laws.need_late_bytes():
  {==}

def Laws.need_far():
  {==}

def Laws.need_far_bytes():
  {==}

def Laws.need_distance():
  {==}

def Laws.need_distance_bytes():
  {==}

def Laws.need_landing_boundary():
  {==}

def Laws.need_landing_boundary_bytes():
  {==}

def Laws.need_landing_boundary_hit():
  {==}

def Laws.need_landing_boundary_hit_bytes():
  {==}

def Laws.need_landing_prev():
  {==}

def Laws.need_landing_prev_bytes():
  {==}

def Laws.need_landing_prev_hit():
  {==}

def Laws.need_landing_prev_hit_bytes():
  {==}

def Laws.need_landing_start():
  {==}

def Laws.need_landing_start_bytes():
  {==}

def Laws.need_fold_kelvin():
  {==}

def Laws.need_fold_kelvin_bytes():
  {==}

def Laws.need_fold_long_s():
  {==}

def Laws.need_fold_long_s_bytes():
  {==}

def Laws.need_fold_sigma():
  {==}

def Laws.need_fold_sigma_bytes():
  {==}

def Laws.need_fold_case():
  {==}

def Laws.need_fold_case_hit():
  {==}

def Laws.need_fold_case_hit_bytes():
  {==}

def Laws.need_wide_before():
  {==}

def Laws.need_wide_before_bytes():
  {==}

def Laws.need_wide_boundary():
  {==}

def Laws.need_wide_boundary_bytes():
  {==}

def Laws.need_wide_class():
  {==}

def Laws.need_wide_class_bytes():
  {==}

def Laws.need_wide_letters():
  {==}

def Laws.need_wide_letters_bytes():
  {==}

def Laws.need_wide_align_bytes():
  {==}

def Laws.need_wide_invalid_bytes():
  {==}

def Laws.need_alt():
  {==}

def Laws.need_alt_bytes():
  {==}

def Laws.need_alt_absent():
  {==}

def Laws.need_alt_absent_bytes():
  {==}

def Laws.need_alt_far():
  {==}

def Laws.need_alt_far_bytes():
  {==}

def Laws.need_alt_fold():
  {==}

def Laws.need_alt_fold_bytes():
  {==}

def Laws.need_unbounded():
  {==}

def Laws.need_unbounded_bytes():
  {==}

def Laws.need_of_cat():
  {==}

def Laws.need_of_alt():
  {==}

def Laws.need_of_optional():
  {==}

def Laws.need_of_unbounded():
  {==}

def Laws.need_of_far():
  {==}

def Laws.need_of_far_bytes():
  {==}

def Laws.need_of_fold():
  {==}

def Laws.need_of_fold_bytes():
  {==}

def Laws.need_of_utf8_bytes():
  {==}

def Laws.need_of_fffd():
  {==}

def Laws.need_of_fffd_bytes():
  {==}

def Laws.need_gate_on():
  {==}

def Laws.need_gate_on_alt():
  {==}

def Laws.need_gate_boundary():
  {==}

def Laws.need_gate_far():
  {==}

def Laws.need_gate_unbounded():
  {==}

def Laws.need_anchor_rare():
  {==}

def Laws.need_anchor_first_on_tie():
  {==}

def Laws.need_anchor_alt_places():
  {==}

def Laws.need_anchor_fold():
  {==}

def Laws.need_anchor_wide_bytes():
  {==}

def Laws.need_anchor_inside():
  {==}

def Laws.need_anchor_inside_bytes():
  {==}

def Laws.need_anchor_inside_absent():
  {==}

def Laws.need_anchor_inside_absent_bytes():
  {==}

def Laws.need_anchor_start_bytes():
  {==}

def Laws.need_anchor_start_none_bytes():
  {==}

def Laws.need_anchor_back_start_bytes():
  {==}

def Laws.need_anchor_back_start():
  {==}

def Laws.need_anchor_back():
  {==}

def Laws.need_anchor_back_bytes():
  {==}

def Laws.need_anchor_clamp():
  {==}

def Laws.need_anchor_clamp_bytes():
  {==}

def Laws.need_anchor_clamp_start():
  {==}

def Laws.need_anchor_clamp_start_bytes():
  {==}

def Laws.need_anchor_fold_hit():
  {==}

def Laws.need_anchor_fold_hit_bytes():
  {==}

def Laws.need_anchor_fold_wide():
  {==}

def Laws.need_anchor_fold_wide_bytes():
  {==}

def Laws.need_anchor_wide():
  {==}

def Laws.need_anchor_wide_hit_bytes():
  {==}

def Laws.need_anchor_far():
  {==}

def Laws.need_anchor_far_bytes():
  {==}

def Laws.need_anchor_back_order():
  {==}

def Laws.need_anchor_back_order_bytes():
  {==}

def Laws.need_anchor_prefix_start():
  {==}

def Laws.need_anchor_prefix_start_bytes():
  {==}
