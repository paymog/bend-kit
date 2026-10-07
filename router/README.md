# router

Prepared HTTP routes. Registration is checked. Resolution picks the most specific path, then the method.

```bend
import bend-kit-router@0.2.0.0/router.bend as Router
import bend-kit-router@0.2.0.0/target.bend as Target
```

`target.bend` is a separate import. `router.bend` uses it and does not re-export it.

`prepare` takes `Entry{method, pattern, action, groups}` values and returns `Result<Error, Table>`. A bad pattern, a bad method, or a duplicate shape fails there. `resolve(table, method, target)` returns the action, the captures, and the matched pattern, or an error for a miss or a method miss. `describe` lists the prepared routes, including methods hidden by a more specific path. `route` is the older pairwise matcher. It does not apply the prepared table's precedence.

`Target.parse` reads a request target and query. It is strict about percent-encoding and UTF-8. `camber` and this package's checks import `bend-kit-router@0.2.0.0`.

`prepare` merges shapes in O(routes²). `resolve` scans O(routes × segments). A `Table` is ordinary data. Building one without `prepare` does not make it valid. The laws cover concrete fixtures of the older matcher. They do not prove the prepared table. The selection rules and the bench are in [bench/README.md](bench/README.md).
