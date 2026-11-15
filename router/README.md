# router

Prepared HTTP routes. Registration is checked. Resolution picks the most specific path, then the method.

```bend
import bend-kit-router@0.2.0.0/router.bend as Router
import bend-kit-router@0.2.0.0/target.bend as Target
```

`target.bend` is a separate import. `router.bend` uses it and does not re-export it.

`prepare(~A, entries)` takes `Entry<A>{method, pattern, action, groups}` values and returns `Result<&2, &2, Error, Table<A>>`. It rejects invalid patterns and methods, duplicate method/shape pairs, and conflicting group ancestry. Different methods can share one shape. `resolve(~A, table, method, target)` returns `Result<&2, &2, Error, Resolved<A>>`. A successful result contains the parsed target and a `Choice<A>`: `Found`, `NotFound`, `MethodMissing`, or generated `Options`. Invalid targets return `BadTarget`. `describe` lists the prepared routes and methods hidden by a more specific path. `route` is the pairwise matcher. It does not apply the prepared table's precedence.

`Target.parse` reads a request target and query. It is strict about percent-encoding and UTF-8. `camber` imports `bend-kit-router@0.2.0.0`. This package's checks import the local files.

`prepare` merges shapes in O(routes²). `resolve` scans O(routes × segments). A `Table` is ordinary data. Building one without `prepare` does not make it valid. The laws cover concrete fixtures of the older matcher. They do not prove the prepared table. The selection rules and the bench are in [bench/README.md](bench/README.md).

| def | result |
|---|---|
| `method.valid(s: String)` | `Bool`; tests whether a method is a nonempty HTTP token. |
