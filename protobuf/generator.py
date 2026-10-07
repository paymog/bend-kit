#!/usr/bin/env python3
"""Generate pure typed proto3 codecs through the standard protoc plugin protocol."""
from __future__ import annotations

import re
from google.protobuf.compiler import plugin_pb2
from google.protobuf.descriptor_pb2 import FieldDescriptorProto as D

RUNTIME = "bend-kit-protobuf@0.1.0.0/protobuf.bend"
KINDS = {1: "double", 2: "float", 3: "int64", 4: "uint64", 5: "int32", 6: "fixed64", 7: "fixed32", 8: "bool", 9: "string", 12: "bytes", 13: "uint32", 15: "sfixed32", 16: "sfixed64", 17: "sint32", 18: "sint64", 14: "enum"}
TYPES = {1: "F.F64", 2: "F32", 3: "P.Word64", 4: "P.Word64", 5: "U32", 6: "P.Word64", 7: "U32", 8: "Bool", 9: "String", 12: "B.Bytes", 13: "U32", 15: "U32", 16: "P.Word64", 17: "U32", 18: "P.Word64"}
WIRE = {1: "Fixed64", 2: "Fixed32", 3: "Varint", 4: "Varint", 5: "Varint", 6: "Fixed64", 7: "Fixed32", 8: "Varint", 9: "Blob", 11: "Blob", 12: "Blob", 13: "Varint", 14: "Varint", 15: "Fixed32", 16: "Fixed64", 17: "Varint", 18: "Varint"}


def name(s):
    return s.lstrip(".").replace("_", "_0").replace(".", "_")

def type_name(s):
    return "PB_" + name(s)


class Model:
    def __init__(self, request):
        options = dict(item.split("=", 1) if "=" in item else (item, "1")
                       for item in request.parameter.split(",") if item)
        if options.keys() - {"runtime_import"}:
            raise ValueError("Unknown generator option")
        self.runtime = options.get("runtime_import", RUNTIME)
        if not re.fullmatch(r"[A-Za-z0-9_./@-]+", self.runtime):
            raise ValueError("Invalid runtime_import")
        self.messages, self.enums = {}, {}
        for file in request.proto_file:
            if file.syntax != "proto3":
                raise ValueError(f"Only proto3 schemas are supported: {file.name}")
            self.walk(file.package, file.message_type, file.enum_type)
        if not request.file_to_generate:
            raise ValueError("No files to generate")

    def walk(self, prefix, messages, enums):
        for enum in enums:
            key = type_name(prefix + "." + enum.name if prefix else enum.name)
            if key in self.messages or key in self.enums:
                raise ValueError(f"Duplicate schema name: {key}")
            self.enums[key] = enum
        for message in messages:
            key = type_name(prefix + "." + message.name if prefix else message.name)
            if key in self.messages or key in self.enums:
                raise ValueError(f"Duplicate schema name: {key}")
            self.messages[key] = message
            self.walk(prefix + "." + message.name if prefix else message.name,
                      message.nested_type, message.enum_type)

    def map(self, f):
        return f.type == D.TYPE_MESSAGE and self.messages[type_name(f.type_name)].options.map_entry

    def groups(self, m):
        return {i: one for i, one in enumerate(m.oneof_decl)
                if not any(f.proto3_optional and f.HasField("oneof_index") and f.oneof_index == i for f in m.field)}

    def slots(self, m):
        groups = self.groups(m)
        seen = set()
        result = []
        for f in m.field:
            group = f.oneof_index if f.HasField("oneof_index") and f.oneof_index in groups else None
            if group is None:
                result.append(("f_" + name(f.name), f, None))
            elif group not in seen:
                result.append(("o_" + name(groups[group].name), f, group))
                seen.add(group)
        return result

    def bare(self, f):
        return type_name(f.type_name) if f.type in (D.TYPE_MESSAGE, D.TYPE_ENUM) else TYPES[f.type]

    def quantity(self, f):
        return "&1" if f.type in (D.TYPE_MESSAGE, D.TYPE_BYTES) else "&2"

    def field_type(self, key, f, group=None):
        if group is not None:
            return f"Maybe<&1, {key}_Choice_{group}>"
        t, q = self.bare(f), self.quantity(f)
        if self.map(f):
            return f"Map<&1, {t}>"
        if f.label == D.LABEL_REPEATED:
            return f"List<{q}, {t}>"
        if f.type == D.TYPE_MESSAGE or f.proto3_optional:
            return f"Maybe<{q}, {t}>"
        return t

    def zero(self, f, group=None):
        if self.map(f):
            return f"Map.new(&1, {self.bare(f)})"
        if group is not None or f.type == D.TYPE_MESSAGE or f.proto3_optional:
            return "None{}" if f.label != D.LABEL_REPEATED else "Nil{}"
        if f.label == D.LABEL_REPEATED:
            return "Nil{}"
        if f.type == D.TYPE_ENUM:
            return self.bare(f) + "{0}"
        return {"F.F64": "F.F64{0, 0}", "F32": "P.float_of_bits(0)", "P.Word64": "P.Word64{0, 0}", "U32": "0", "Bool": "False{}", "String": '""', "B.Bytes": "B.new(0)"}[self.bare(f)]


class Emitter:
    def __init__(self, model):
        self.m = model
        self.types = []
        self.defs = {}

    def add(self, signature, body):
        key = signature.split("(", 1)[0]
        if key in self.defs:
            raise ValueError(f"Duplicate generated definition: {key}")
        self.defs[key] = ["def " + signature + ":", *body, ""]

    def result(self, t, q="&1"):
        return f"Result<&2, {q}, P.Error, {t}>"

    def record(self, key, updates=None):
        updates = updates or {}
        slots = [x[0] for x in self.m.slots(self.m.messages[key])] + ["unknown"]
        return key + "{" + ", ".join(updates.get(s, s) for s in slots) + "}"

    def opened(self, key):
        slots = [x[0] for x in self.m.slots(self.m.messages[key])] + ["unknown"]
        return key + "{" + ", ".join(slots) + "} = cur"

    def boxed(self, key, record):
        return f"Box_{key}{{{record}}}"

    def field_slot(self, key, f):
        for slot, first, group in self.m.slots(self.m.messages[key]):
            if first.number == f.number or (group is not None and f.HasField("oneof_index") and f.oneof_index == group):
                return slot, group
        raise ValueError("Missing field slot")

    def generate_types(self):
        for key, enum in self.m.enums.items():
            self.types += [f"type {key} is Data:", f"  {key}{{number: U32}}", ""]
            for val in enum.value:
                self.add(f"{key}.{name(val.name)}() -> {key}", [f"  {key}{{{val.number & 0xffffffff}}}"])
        for key, m in self.m.messages.items():
            for group in self.m.groups(m):
                self.types += [f"type {key}_Choice_{group} is Type:"]
                self.types += [f"  Case_{key}_{f.number}{{value: {self.m.bare(f)}}}" for f in m.field if f.HasField("oneof_index") and f.oneof_index == group]
                self.types.append("")
            slots = self.m.slots(m)
            fields = [f"{s}: {self.m.field_type(key, f, g)}" for s, f, g in slots] + ["unknown: List<&1, P.Field>"]
            self.types += [f"type {key} is Type:", f"  {key}{{{', '.join(fields)}}}", ""]
            zero = ", ".join([self.m.zero(f, g) for _, f, g in slots] + ["Nil{}"])
            self.add(f"{key}.empty() -> {key}", [f"  {key}{{{zero}}}"])
        self.types += ["type Msg is Type:", *[f"  Box_{key}{{value: {key}}}" for key in self.m.messages], "", "type Act is Type:", "  Stay{value: Msg}", "  Down{bytes: B.Bytes, seed: Msg, resume: Msg -> Result<&2, &1, P.Error, Msg>}", "  Bad{error: P.Error}", "", "type Job is Type:", "  Plain{field: P.Field}", "  Child{number: U32, value: Msg}", ""]
        self.types += ["type Final is Type:", "  Complete{value: Msg}", "  Visit{value: Msg, resume: Msg -> Final}", "  BadFinal{error: P.Error}", ""]

    def common(self):
        rmsg, rfields, rbytes, rjobs = [self.result(t) for t in ("Msg", "List<&1, P.Field>", "B.Bytes", "List<&1, Job>")]
        self.add("nested(e: P.Error) -> P.Error", ["  match e:", "    case P.Incomplete{}: P.Malformed{}", "    case P.Malformed{}: P.Malformed{}", "    case P.Limit{}: P.Limit{}", "    case P.InvalidUtf8{}: P.InvalidUtf8{}"])
        self.add(f"run_resumed(r: {rmsg}, next: Msg -> {rmsg}) -> {rmsg}", ["  match r:", "    case Fail{e}: Fail{e}", "    case Done{v}: next(v)"])
        self.add(f"run_child(r: {rmsg}, resume: Msg -> {rmsg}, next: Msg -> {rmsg}) -> {rmsg}", ["  match r:", "    case Fail{e}: Fail{nested(e)}", "    case Done{v}: run_resumed(resume(v), next)"])
        self.add(f"run_blob(r: {rfields}, seed: Msg, resume: Msg -> {rmsg}, descend: List<&1, P.Field> -> Msg -> {rmsg}, next: Msg -> {rmsg}) -> {rmsg}", ["  match r:", "    case Fail{e}: Fail{nested(e)}", "    case Done{fields}: run_child(descend(fields, seed), resume, next)"])
        self.add(f"run_allowed(allow: Bool, b: B.Bytes, seed: Msg, resume: Msg -> {rmsg}, +size: U32, depth: Nat, descend: List<&1, P.Field> -> Msg -> {rmsg}, next: Msg -> {rmsg}) -> {rmsg}", ["  match allow:", "    case False{}: Fail{P.Limit{}}", "    case True{}: run_blob(P.decode(b, size, depth), seed, resume, descend, next)"])
        self.add(f"run_act(act: Act, allow: Bool, size: U32, depth: Nat, descend: List<&1, P.Field> -> Msg -> {rmsg}, next: Msg -> {rmsg}) -> {rmsg}", ["  match act:", "    case Bad{e}: Fail{e}", "    case Stay{v}: next(v)", "    case Down{b, seed, resume}: run_allowed(allow, b, seed, resume, size, depth, descend, next)"])
        self.add(f"start_jobs(r: {rjobs}, next: List<&1, Job> -> {rfields}) -> {rfields}", ["  match r:", "    case Fail{e}: Fail{e}", "    case Done{jobs}: next(jobs)"])
        self.add(f"encoded_child(r: {rbytes}, next: B.Bytes -> {rfields}) -> {rfields}", ["  match r:", "    case Fail{e}: Fail{e}", "    case Done{bytes}: next(bytes)"])
        self.add(f"encode_child(r: {rfields}, size: U32, depth: Nat, next: B.Bytes -> {rfields}) -> {rfields}", ["  match r:", "    case Fail{e}: Fail{e}", "    case Done{fields}: encoded_child(P.encode(fields, size, depth), next)"])
        self.add(f"encode_result(r: {rfields}, size: U32, depth: Nat) -> {rbytes}", ["  match r:", "    case Fail{e}: Fail{e}", "    case Done{fields}: P.encode(fields, size, depth)"])
        self.add("unknown_jobs(fields: List<&1, P.Field>) -> List<&1, Job>", ["  match fields:", "    case Nil{}: Nil{}", "    case Con{h, t}: Con{Plain{h}, unknown_jobs(t)}"])
        self.add(f"plain_value(r: {self.result('P.Value')}, number: U32) -> {rjobs}", ["  match r:", "    case Fail{e}: Fail{e}", "    case Done{v}: Done{[Plain{P.Field{number, v}}]}"])
        self.add(f"packed_value(r: {rbytes}, number: U32) -> {rjobs}", ["  match r:", "    case Fail{e}: Fail{e}", "    case Done{b}: Done{[Plain{P.Field{number, P.Blob{b}}}]}"])
        self.add("zero_double(w: F.F64) -> Bool", ["  F.F64{h, l} = w", "  U32.is_zero(h) && U32.is_zero(l)"])
        self.add("finish_result(-A: Type, r: Result<&2, &1, P.Error, A>, next: A -> Final) -> Final", ["  match r:", "    case Fail{e}: BadFinal{e}", "    case Done{v}: next(v)"])
        self.add(f"finish_complete(stack: List<&1, Msg -> Final>, value: Msg, next: Final -> List<&1, Msg -> Final> -> {rmsg}) -> {rmsg}", ["  match stack:", "    case Nil{}: Done{value}", "    case Con{resume, tail}: next(resume(value), tail)"])

    def conversions(self):
        used = {f.type for m in self.m.messages.values() for f in m.field if f.type != D.TYPE_MESSAGE}
        specs = [(KINDS[k], TYPES[k], "&1" if k == D.TYPE_BYTES else "&2", k) for k in used if k != D.TYPE_ENUM]
        specs += [(key, key, "&2", D.TYPE_ENUM) for key in self.m.enums]
        for kind, t, q, k in specs:
            read = f"P.to_{KINDS[k]}(value)" if k != D.TYPE_ENUM else f"enum_read_{kind}(P.to_int32(value))"
            if k == D.TYPE_ENUM:
                self.add(f"enum_read_{kind}(r: {self.result('U32', '&2')}) -> {self.result(t, q)}", ["  match r:", "    case Fail{e}: Fail{e}", f"    case Done{{v}}: Done{{{t}{{v}}}}"])
            self.add(f"read_{kind}(value: P.Value) -> {self.result(t, q)}", ["  " + read])
            cv = "P.from_string(x)" if k == D.TYPE_STRING else f"Done{{P.from_{KINDS[k]}(x)}}"
            body = ["  " + cv]
            if k == D.TYPE_ENUM:
                body = [f"  {t}{{n}} = x", "  Done{P.from_int32(n)}"]
            self.add(f"value_{kind}(x: {t}) -> {self.result('P.Value')}", body)
            self.add(f"read_list_{kind}(xs: List<&1, P.Value>) -> {self.result(f'List<{q}, {t}>', q)}", ["  match xs:", "    case Nil{}: Done{Nil{}}", "    case Con{h, t}:", f"      do Result<&2, {q}, P.Error, List<{q}, {t}>>:", f"        x : {t} <- read_{kind}(h)", f"        tail : List<{q}, {t}> <- read_list_{kind}(t)", "        return Con{x, tail}"])
            self.add(f"value_list_{kind}(xs: List<{q}, {t}>) -> {self.result('List<&1, P.Value>')}", ["  match xs:", "    case Nil{}: Done{Nil{}}", "    case Con{h, t}:", "      do Result<&2, &1, P.Error, List<&1, P.Value>>:", f"        x : P.Value <- value_{kind}(h)", f"        tail : List<&1, P.Value> <- value_list_{kind}(t)", "        return Con{x, tail}"])
            self.add(f"packed_list_{kind}(r: {self.result('List<&1, P.Value>')}, number: U32, size: U32) -> {self.result('List<&1, Job>')}", ["  match r:", "    case Fail{e}: Fail{e}", "    case Done{values}: packed_value(P.packed_encode(values, size), number)"])
            self.add(f"unpacked_list_{kind}(xs: List<{q}, {t}>, +number: U32) -> {self.result('List<&1, Job>')}", ["  match xs:", "    case Nil{}: Done{Nil{}}", "    case Con{h, t}:", "      do Result<&2, &1, P.Error, List<&1, Job>>:", f"        value : P.Value <- value_{kind}(h)", f"        tail : List<&1, Job> <- unpacked_list_{kind}(t, number)", "        return Con{Plain{P.Field{number, value}}, tail}"])

    def kind(self, f):
        return type_name(f.type_name) if f.type == D.TYPE_ENUM else KINDS[f.type]

    def map_helpers(self, key, m):
        if not m.options.map_entry:
            return
        kt = self.m.bare(m.field[0])
        if kt == "String":
            body = ["  x"]
        elif kt == "P.Word64":
            body = ["  P.Word64{h, l} = x", '  U32.show(h) ++ ":" ++ U32.show(l)']
        elif kt == "Bool":
            body = ["  U32.show(Bool.to_u32(x))"]
        else:
            body = ["  U32.show(x)"]
        self.add(f"map_key_{key}(x: {kt}) -> String", body)
        self.add(f"map_insert_{key}(entry: {key}, xs: Map<&1, {key}>) -> Map<&1, {key}>", [f"  {key}{{+k, v, unknown}} = entry", f"  Map.set(&1, {key}, xs, map_key_{key}(k), {key}{{k, v, unknown}})"])

    def finalizer(self, key, m):
        # Children remain reverse accumulators until this retained-tree traversal.
        cast = f"finish_result({key}, cast_{key}(box),"
        self.add(f"finish_optional_{key}(x: Maybe<&1, {key}>, next: Maybe<&1, {key}> -> Final) -> Final", [
            "  match x:",
            "    case None{}: next(None{})",
            f"    case Some{{v}}: Visit{{Box_{key}{{v}}, box => {cast} child => next(Some{{child}}))}}"])
        self.add(f"finish_list_{key}(xs: List<&1, {key}>, acc: List<&1, {key}>, next: List<&1, {key}> -> Final) -> Final", [
            "  match xs:",
            "    case Nil{}: next(acc)",
            f"    case Con{{h, t}}: Visit{{Box_{key}{{h}}, box => {cast} child => finish_list_{key}(t, Con{{child, acc}}, next))}}"])
        self.add(f"finish_map_{key}(xs: Map<&1, {key}>, next: Map<&1, {key}> -> Final) -> Final", [
            "  match xs:",
            "    case MTip{}: next(MTip{})",
            f"    case MLeaf{{k, v}}: Visit{{Box_{key}{{v}}, box => {cast} child => next(MLeaf{{k, child}}))}}",
            f"    case MNode{{pos, lo, hi}}: finish_map_{key}(lo, left => finish_map_{key}(hi, right => next(MNode{{pos, left, right}})))"])
        updates, walkers = {}, []
        for slot, f, group in self.m.slots(m):
            if group is not None:
                members = [other for other in m.field if other.HasField("oneof_index") and other.oneof_index == group]
                if not any(other.type == D.TYPE_MESSAGE for other in members):
                    continue
                helper = f"finish_choice_{key}_{group}"
                typ = self.m.field_type(key, f, group)
                body = ["  match x:", "    case None{}: next(None{})", "    case Some{choice}:", "      match choice:"]
                for other in members:
                    stored = f"Some{{Case_{key}_{other.number}{{child}}}}"
                    if other.type == D.TYPE_MESSAGE:
                        target = self.m.bare(other)
                        value = f"Visit{{Box_{target}{{v}}, box => finish_result({target}, cast_{target}(box), child => next({stored}))}}"
                    else:
                        value = f"next(Some{{Case_{key}_{other.number}{{v}}}})"
                    body.append(f"        case Case_{key}_{other.number}{{v}}: {value}")
                self.add(f"{helper}(x: {typ}, next: {typ} -> Final) -> Final", body)
                walkers.append((slot, f"{helper}({slot},"))
            elif f.type == D.TYPE_MESSAGE:
                target = self.m.bare(f)
                if self.m.map(f):
                    walk = f"finish_map_{target}({slot},"
                elif f.label == D.LABEL_REPEATED:
                    walk = f"finish_list_{target}({slot}, Nil{{}},"
                else:
                    walk = f"finish_optional_{target}({slot},"
                walkers.append((slot, walk))
            elif f.label == D.LABEL_REPEATED:
                updates[slot] = f"List.reverse({self.m.quantity(f)}, {self.m.bare(f)}, {slot})"
        updates.update({slot: slot + "_final" for slot, _ in walkers})
        updates["unknown"] = "List.reverse(&1, P.Field, unknown)"
        value = "Complete{" + self.boxed(key, self.record(key, updates)) + "}"
        for slot, walk in reversed(walkers):
            value = f"{walk} {slot}_final => {value})"
        self.add(f"finish_{key}(cur: {key}) -> Final", ["  " + self.opened(key), "  " + value])

    def message(self, key, m):
        slots = self.m.slots(m)
        self.map_helpers(key, m)
        self.finalizer(key, m)
        self.add(f"cast_{key}(box: Msg) -> {self.result(key)}", ["  match box:", f"    case Box_{key}{{v}}: Done{{v}}", *[f"    case Box_{other}{{v}}: Fail{{P.Malformed{{}}}}" for other in self.m.messages if other != key]])
        self.add(f"keep_{key}(number: U32, value: P.Value, cur: {key}) -> Act", ["  " + self.opened(key), "  Stay{" + self.boxed(key, self.record(key, {"unknown": "Con{P.Field{number, value}, unknown}"})) + "}"])
        chain = f"keep_{key}(number, value, cur)"
        for f in reversed(m.field):
            if f.type not in WIRE:
                raise ValueError("Unsupported proto3 field type")
            fn = f"choose_{key}_{f.number}"
            self.add(f"{fn}(same: Bool, +number: U32, value: P.Value, cur: {key}, size: U32) -> Act", ["  match same:", "    case False{}: " + chain, f"    case True{{}}: use_{key}_{f.number}(value, cur, size)"])
            chain = f"{fn}(U32.is_eq(number, {f.number}), number, value, cur, size)"
            self.decoder_field(key, f)
            self.encoder_field(key, f)
        self.add(f"choose_{key}(field: P.Field, cur: {key}, size: U32) -> Act", ["  P.Field{+number, value} = field", "  " + chain])
        self.add(f"jobs_{key}(cur: {key}, +size: U32) -> {self.result('List<&1, Job>')}", ["  " + self.opened(key), "  do Result<&2, &1, P.Error, List<&1, Job>>:", *[f"    j{i} : List<&1, Job> <- emit_{key}_{f.number}({s}, size)" for i, (s, f, g) in enumerate(slots)], "    return " + self.job_append(len(slots), "unknown_jobs(unknown)")])
        # Each child needs two wire bytes and two pump steps; the root needs one.
        self.add(f"decode_{key}(b: B.Bytes, +size: U32, +depth: Nat) -> {self.result(key)}", ["  B.Bytes{+n, buf} = b", f"  do Result<&2, &1, P.Error, {key}>:", "    fields : List<&1, P.Field> <- P.decode(B.Bytes{n, buf}, size, depth)", f"    raw : Msg <- decode_go(depth, size, fields, Box_{key}{{{key}.empty()}})", "    box : Msg <- finish_go(Succ{U32.to_nat(n)}, finish_msg(raw), Nil{})", f"    cast_{key}(box)"])
        self.add(f"encode_{key}(cur: {key}, +size: U32, +depth: Nat) -> {self.result('B.Bytes')}", [f"  encode_result(start_jobs(jobs_{key}(cur, size), jobs => encode_go(depth, size, jobs, Nil{{}})), size, depth)"])

    def job_append(self, count, tail):
        for i in reversed(range(count)):
            tail = f"List.append(&1, Job, j{i}, {tail})"
        return tail

    def decoder_field(self, key, f):
        slot, group = self.field_slot(key, f)
        known = WIRE[f.type]
        accepted = {known}
        numeric = f.type not in (D.TYPE_MESSAGE, D.TYPE_BYTES, D.TYPE_STRING)
        if f.label == D.LABEL_REPEATED and numeric:
            accepted.add("Blob")
        body = ["  match value:"]
        for variant in ("Varint", "Fixed32", "Fixed64", "Blob", "Group"):
            body += [f"    case P.{variant}{{x}}:"]
            val = f"P.{variant}{{x}}"
            if variant not in accepted:
                body += [f"      keep_{key}({f.number}, {val}, cur)"]
            elif f.type == D.TYPE_MESSAGE:
                body += [f"      down_{key}_{f.number}(x, cur)"]
            elif f.label == D.LABEL_REPEATED and variant == "Blob" and numeric:
                wire = {"Varint": 0, "Fixed64": 1, "Fixed32": 5}[known]
                body += [f"      packed_{key}_{f.number}(P.packed_decode({wire}, x, size), cur)"]
            else:
                body += [f"      got_{key}_{f.number}(read_{self.kind(f)}({val}), cur)"]
        self.add(f"use_{key}_{f.number}(value: P.Value, cur: {key}, size: U32) -> Act", body)
        if f.type == D.TYPE_MESSAGE:
            target = self.m.bare(f)
            # Old child is moved into the recursive decoder, never copied or merged after presence is lost.
            body = ["  " + self.opened(key)]
            if f.label == D.LABEL_REPEATED:
                seed = f"Box_{target}{{{target}.empty()}}"
                update = f"map_insert_{target}(child, {slot})" if self.m.map(f) else f"Con{{child, {slot}}}"
                body += [f"  Down{{b, {seed}, box => resume_{key}_{f.number}(box, {', '.join([s for s, _, _ in self.m.slots(self.m.messages[key])] + ['unknown'])})}}"]
                args = ", ".join(f"{s}: {self.m.field_type(key, sf, sg)}" for s, sf, sg in self.m.slots(self.m.messages[key])) + ", unknown: List<&1, P.Field>"
                self.add(f"resume_{key}_{f.number}(box: Msg, {args}) -> {self.result('Msg')}", self.resume_body(key, target, slot, update))
            else:
                others = [s for s, _, _ in self.m.slots(self.m.messages[key]) if s != slot] + ["unknown"]
                args = ", ".join(f"{s}: {self.m.field_type(key, sf, sg)}" for s, sf, sg in self.m.slots(self.m.messages[key]) if s != slot)
                args = (args + ", " if args else "") + "unknown: List<&1, P.Field>"
                body += [f"  seed_down_{key}_{f.number}({slot}, b, {', '.join(others)})"]
                oldtype = self.m.field_type(key, f, group)
                sb = ["  match old:"]
                stored = "Some{child}" if group is None else f"Some{{Case_{key}_{f.number}{{child}}}}"
                resume = f"box => resume_{key}_{f.number}(box, {', '.join(others)})"
                if group is None:
                    sb += [f"    case None{{}}: Down{{b, {self.boxed(target, target + '.empty()')}, {resume}}}", f"    case Some{{v}}: Down{{b, {self.boxed(target, 'v')}, {resume}}}"]
                else:
                    sb += [f"    case None{{}}: Down{{b, {self.boxed(target, target + '.empty()')}, {resume}}}", "    case Some{choice}:", "      match choice:"]
                    for other in self.m.messages[key].field:
                        if other.HasField("oneof_index") and other.oneof_index == group:
                            childseed = "v" if other.number == f.number else f"{target}.empty()"
                            sb += [f"        case Case_{key}_{other.number}{{v}}: Down{{b, {self.boxed(target, childseed)}, {resume}}}"]
                self.add(f"seed_down_{key}_{f.number}(old: {oldtype}, b: B.Bytes, {args}) -> Act", sb)
                self.add(f"resume_{key}_{f.number}(box: Msg, {args}) -> {self.result('Msg')}", self.resume_body(key, target, slot, stored))
            self.add(f"down_{key}_{f.number}(b: B.Bytes, cur: {key}) -> Act", body)
            return
        t, q, kind = self.m.bare(f), self.m.quantity(f), self.kind(f)
        value = "x"
        if f.label == D.LABEL_REPEATED:
            value = f"Con{{x, {slot}}}"
        elif group is not None:
            value = f"Some{{Case_{key}_{f.number}{{x}}}}"
        elif f.proto3_optional:
            value = "Some{x}"
        self.add(f"got_{key}_{f.number}(r: {self.result(t, q)}, cur: {key}) -> Act", ["  match r:", "    case Fail{e}: Bad{e}", "    case Done{x}:", "      " + self.opened(key), "      Stay{" + self.boxed(key, self.record(key, {slot: value})) + "}"])
        if f.label == D.LABEL_REPEATED and numeric:
            self.add(f"packed_{key}_{f.number}(r: {self.result('List<&1, P.Value>')}, cur: {key}) -> Act", ["  match r:", "    case Fail{e}: Bad{e}", f"    case Done{{xs}}: packed_got_{key}_{f.number}(read_list_{kind}(xs), cur)"])
            self.add(f"packed_got_{key}_{f.number}(r: {self.result(f'List<{q}, {t}>', q)}, cur: {key}) -> Act", ["  match r:", "    case Fail{e}: Bad{e}", "    case Done{xs}:", "      " + self.opened(key), "      Stay{" + self.boxed(key, self.record(key, {slot: f"List.reverse.go({q}, {t}, xs, {slot})"})) + "}"])

    def resume_body(self, key, target, slot, value):
        return ["  match box:", f"    case Box_{target}{{child}}: Done{{" + self.boxed(key, self.record(key, {slot: value})) + "}", *[f"    case Box_{other}{{child}}: Fail{{P.Malformed{{}}}}" for other in self.m.messages if other != target]]

    def encoder_field(self, key, f):
        slot, group = self.field_slot(key, f)
        if group is not None:
            first = next(first for s, first, _ in self.m.slots(self.m.messages[key]) if s == slot)
            if first.number != f.number:
                return
        t = self.m.field_type(key, f, group)
        rjobs = self.result("List<&1, Job>")
        body = []
        if group is not None:
            body = ["  match x:", "    case None{}: Done{Nil{}}", "    case Some{choice}:", "      match choice:"]
            for other in self.m.messages[key].field:
                if other.HasField("oneof_index") and other.oneof_index == group:
                    value = f"Done{{[Child{{{other.number}, Box_{self.m.bare(other)}{{v}}}}]}}" if other.type == D.TYPE_MESSAGE else f"plain_value(value_{self.kind(other)}(v), {other.number})"
                    body += [f"        case Case_{key}_{other.number}{{v}}: {value}"]
        elif f.label == D.LABEL_REPEATED:
            if f.type == D.TYPE_MESSAGE:
                target = self.m.bare(f)
                walker = f"emit_map_list_{key}_{f.number}" if self.m.map(f) else f"emit_{key}_{f.number}"
                body = ["  match x:", "    case Nil{}: Done{Nil{}}", "    case Con{h, t}:", "      do Result<&2, &1, P.Error, List<&1, Job>>:", f"        tail : List<&1, Job> <- {walker}(t, size)", f"        return Con{{Child{{{f.number}, Box_{target}{{h}}}}, tail}}"]
                if self.m.map(f):
                    self.add(f"{walker}(x: List<&1, {target}>, +size: U32) -> {rjobs}", body)
                    body = [f"  {walker}(Map.values(&1, {target}, x), size)"]
            else:
                packed = WIRE[f.type] in ("Varint", "Fixed32", "Fixed64") and (not f.options.HasField("packed") or f.options.packed)
                if packed:
                    body = ["  match x:", "    case Nil{}: Done{Nil{}}", f"    case Con{{h, t}}: packed_list_{self.kind(f)}(value_list_{self.kind(f)}(Con{{h, t}}), {f.number}, size)"]
                else:
                    body = [f"  unpacked_list_{self.kind(f)}(x, {f.number})"]
        elif f.type == D.TYPE_MESSAGE or f.proto3_optional:
            call = f"Done{{[Child{{{f.number}, Box_{self.m.bare(f)}{{v}}}}]}}" if f.type == D.TYPE_MESSAGE else f"plain_value(value_{self.kind(f)}(v), {f.number})"
            body = ["  match x:", "    case None{}: Done{Nil{}}", "    case Some{v}: " + call]
        else:
            typ = self.m.bare(f)
            if typ == "B.Bytes":
                body = ["  B.Bytes{+n, buf} = x", f"  emit_bytes_{key}_{f.number}(U32.is_zero(n), B.Bytes{{n, buf}})"]
                self.add(f"emit_bytes_{key}_{f.number}(empty: Bool, b: B.Bytes) -> {rjobs}", ["  match empty:", "    case True{}: Done{Nil{}}", f"    case False{{}}: plain_value(value_bytes(b), {f.number})"])
            else:
                if typ == "P.Word64":
                    condition = "P.Word64.is_zero(x)"
                elif typ == "F.F64":
                    condition = "zero_double(x)"
                elif typ == "F32":
                    condition = "U32.is_zero(F32.bits(x))"
                elif typ == "String":
                    condition = "String.is_empty(x)"
                elif typ == "Bool":
                    condition = "Bool.not(x)"
                elif f.type == D.TYPE_ENUM:
                    condition = f"enum_zero_{typ}(x)"
                else:
                    condition = "U32.is_zero(x)"
                body = [f"  emit_nonzero_{key}_{f.number}({condition}, x)"]
                self.add(f"emit_nonzero_{key}_{f.number}(empty: Bool, x: {typ}) -> {rjobs}", ["  match empty:", "    case True{}: Done{Nil{}}", f"    case False{{}}: plain_value(value_{self.kind(f)}(x), {f.number})"])
        mark = "+" if f.label != D.LABEL_REPEATED and group is None and not f.proto3_optional and self.m.quantity(f) == "&2" else ""
        self.add(f"emit_{key}_{f.number}({mark}x: {t}, +size: U32) -> {rjobs}", body)

    def dispatch(self):
        rmsg, rfields = self.result("Msg"), self.result("List<&1, P.Field>")
        self.add("finish_msg(box: Msg) -> Final", ["  match box:", *[f"    case Box_{key}{{v}}: finish_{key}(v)" for key in self.m.messages]])
        self.add(f"finish_go(fuel: Nat, step: Final, stack: List<&1, Msg -> Final>) -> {rmsg}", ["  match fuel:", "    case 0n: Fail{P.Limit{}}", "    case 1n+p:", "      match step:", "        case BadFinal{e}: Fail{e}", "        case Visit{v, resume}: finish_go(p, finish_msg(v), Con{resume, stack})", "        case Complete{v}: finish_complete(stack, v, next => rest => finish_go(p, next, rest))"])
        self.add("choose(field: P.Field, box: Msg, size: U32) -> Act", ["  match box:", *[f"    case Box_{key}{{v}}: choose_{key}(field, v, size)" for key in self.m.messages]])
        self.add(f"jobs_msg(box: Msg, size: U32) -> {self.result('List<&1, Job>')}", ["  match box:", *[f"    case Box_{key}{{v}}: jobs_{key}(v, size)" for key in self.m.messages]])
        body = ["  match depth:"]
        for pattern, childdepth, allow in (("0n", "0n", "False{}"), ("1n+p", "p", "True{}")):
            d = "0n" if pattern == "0n" else "1n+p"
            descend = "fields => seed => Fail{P.Limit{}}" if pattern == "0n" else "fields => seed => decode_go(p, size, fields, seed)"
            body += [f"    case {pattern}:", "      match fields:", "        case Nil{}: Done{cur}", "        case Con{h, t}:", f"          run_act(choose(h, cur, size), {allow}, size, {childdepth}, {descend}, next => decode_go({d}, size, t, next))"]
        self.add(f"decode_go(+depth: Nat, +size: U32, fields: List<&1, P.Field>, cur: Msg) -> {rmsg}", body)
        body = ["  match depth:"]
        for pattern in ("0n", "1n+p"):
            d = "0n" if pattern == "0n" else "1n+p"
            child = "Fail{P.Limit{}}" if pattern == "0n" else "start_jobs(jobs_msg(v, size), child_jobs => encode_child(encode_go(p, size, child_jobs, Nil{}), size, p, b => encode_go(1n+p, size, t, Con{P.Field{number, P.Blob{b}}, acc})))"
            body += [f"    case {pattern}:", "      match jobs:", "        case Nil{}: Done{List.reverse(&1, P.Field, acc)}", "        case Con{h, t}:", "          match h:", f"            case Plain{{field}}: encode_go({d}, size, t, Con{{field, acc}})", f"            case Child{{number, v}}: {child}"]
        self.add(f"encode_go(+depth: Nat, +size: U32, jobs: List<&1, Job>, acc: List<&1, P.Field>) -> {rfields}", body)
        for key in self.m.enums:
            self.add(f"enum_zero_{key}(x: {key}) -> Bool", [f"  {key}{{n}} = x", "  U32.is_zero(n)"])

    def render(self):
        self.generate_types()
        self.common()
        self.conversions()
        for key, m in self.m.messages.items():
            self.message(key, m)
        self.dispatch()
        # Callback bodies keep every recursive call in its one dispatcher definition.
        names = set(self.defs)
        calls = re.compile(r"(?<![A-Za-z0-9_.])(" + "|".join(map(re.escape, names)) + r")\(")
        dependencies = {k: set(calls.findall("\n".join(v[1:]))) - {k} for k, v in self.defs.items()}
        roots = {f"{key}.empty" for key in self.m.messages}
        roots |= {f"{verb}_{key}" for key in self.m.messages for verb in ("encode", "decode")}
        roots |= {f"{key}.{name(v.name)}" for key, e in self.m.enums.items() for v in e.value}
        reachable, work = set(), list(roots)
        while work:
            key = work.pop()
            if key not in reachable:
                reachable.add(key)
                work.extend(dependencies[key])
        ordered = []
        pending = {k: v for k, v in self.defs.items() if k in reachable}
        while pending:
            ready = [k for k in pending if not (dependencies[k] & pending.keys())]
            if not ready:
                raise ValueError("Generated definition cycle: " + ", ".join(pending))
            for k in ready:
                ordered.extend(pending.pop(k))
        imports = ["# Pure typed proto3 codecs generated by protoc-gen-bend.", "import Base", "import bend-kit-bytes@0.3.2.0/bytes.bend as B", "import bend-kit-f64@0.1.0.0/f64.bend as F", f"import {self.m.runtime} as P", ""]
        return "\n".join(imports + self.types + ordered) + "\n"


def generate(data):
    request = plugin_pb2.CodeGeneratorRequest.FromString(data)
    response = plugin_pb2.CodeGeneratorResponse(supported_features=plugin_pb2.CodeGeneratorResponse.FEATURE_PROTO3_OPTIONAL)
    try:
        model = Model(request)
        response.file.add(name="schema.bend", content=Emitter(model).render())
    except (ValueError, KeyError) as e:
        response.error = str(e)
    return response.SerializeToString()
