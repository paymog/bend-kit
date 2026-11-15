# authz

Pure authorization policies. A policy decides one request: Allow, Deny, or Abstain. Only Allow grants. An explicit deny overrides every allow, and missing information fails closed.

```bend
import bend-kit-authz@0.1.0.0/authz.bend as Az
```

## Example

```bend
import Base
import bend-kit-authz@0.1.0.0/authz.bend as Az

# Owners delete their documents. Admins delete any document. A suspended role always denies.
def documents() -> Az.Policy:
  Az.DenyOverrides{
    Az.DenyOverrides{Az.Permit{Az.AllOf{Az.Action{"DELETE"}, Az.Owner{}}}, Az.Permit{Az.Role{"admin"}}},
    Az.Forbid{Az.Role{"suspended"}}}

def main() -> Bool:
  Az.granted(documents(), Az.Request{Some{"alice"}, Some{["editor"]}, Some{"alice"}, "DELETE", "/docs/1"})
```

`main` answers `True{}`. With roles `["editor", "suspended"]` it answers `False{}`. With subject `None{}` it answers `False{}`.

## Model

| type | values |
|---|---|
| `Request` | `subject`, `roles`, and `owner` are `Maybe`; `None{}` is missing information. `action` and `resource` are always known. |
| `Target` | `Everyone`, `Nobody`, `Action{name}`, `Resource{name}`, `Subject{name}`, `Role{name}`, `Owner` (subject equals owner), `AllOf{a, b}` |
| `Tri` | `Yes`, `No`, or `Unknown` when a target needs a missing field. `AllOf` is Kleene conjunction: `No` wins, then `Unknown`. |
| `Decision` | `Allow`, `Deny`, or `Abstain` (no rule applies) |
| `Policy` | `Permit{t}`, `Forbid{t}`, `DenyOverrides{a, b}`, `Intersect{a, b}` |

| target answer | `Permit{t}` | `Forbid{t}` |
|---|---|---|
| `Yes` | `Allow` | `Deny` |
| `No` | `Abstain` | `Abstain` |
| `Unknown` | `Abstain` | `Deny` |

| combine | answer |
|---|---|
| `DenyOverrides{a, b}` | `Deny` if either denies, else `Allow` if either allows, else `Abstain` |
| `Intersect{a, b}` | `Deny` if either denies, else `Allow` if both allow, else `Abstain` |

`decide(p, req)` answers the `Decision`. `granted(p, req)` answers `True{}` only for `Allow`: default deny. Use `DenyOverrides` to add rules, and `Intersect` to restrict a policy by another.

| def | returns |
|---|---|
| `matches(t: Target, +req: Request) -> Tri` | `Yes`, `No`, or `Unknown` for the target and request. |

## Laws

`LAWS.bend` states these for every policy, target, and request. `PROOF.bend` proves them.

| law | claim |
|---|---|
| `deny_overrides_left`, `deny_overrides_right` | if either side denies, `DenyOverrides` denies |
| `deny_intersect` | if the left side denies, `Intersect` denies |
| `default_deny` | an `Abstain` decision is not granted |
| `intersect_grants` | `Intersect{p, q}` grants exactly when both `p` and `q` grant |
| `restrict_narrows` | `Intersect{p, q}` grants only what `p` grants |
| `forbid_narrows` | `DenyOverrides{p, Forbid{t}}` grants only what `p` grants |
| `missing_never_grants` | if a request with missing fields is granted, every request that fills them in is granted too. Missing information never grants what the full information would not. |
| `forbid_unknown_denies` | a forbid whose target needs a missing field denies |
| `deny_overrides_comm`, `deny_overrides_assoc`, `deny_overrides_idem`, `deny_overrides_unit` | `DenyOverrides` is commutative, associative, and idempotent, with unit `Permit{Nobody}` |
| `intersect_comm`, `intersect_assoc`, `intersect_idem`, `intersect_unit` | `Intersect` is commutative, associative, and idempotent, with unit `Permit{Everyone}` |

## Trust boundary

- The laws are about pure evaluation and composition. They do not prove that role assignments are correct, that a JWT signature is valid, where an identity came from, or that an owner lookup is fresh. Verify identity first (for example with `jwt`), then build the `Request`.
- A `None{}` field means "not known". Do not write `Some{""}` or `Some{Nil{}}` for an unknown subject or role list: those are known values, and they can match.
- The laws do not prove that a route uses the policy. The caller must run `granted` before the protected operation, and must not run the operation when it answers `False{}`.
- String comparison is exact. Normalize case and encoding before you build the request.

## Checks

`bend check.bend` guards one Camber route, `DELETE /docs/:id`, with a route `before` hook that runs `granted` and answers 403 on denial. It checks the status and the list of protected effects for each case: an owner and an admin are allowed and the delete runs; a non-owner, a suspended owner, a suspended admin, a missing subject, a missing owner, and missing roles get 403 with no delete; and a read-only `Intersect` restriction turns both allowed deletes into 403 with no delete. `bench/` times policy evaluation. See [bench/README.md](bench/README.md).
