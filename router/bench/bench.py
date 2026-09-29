"""Router benchmark in Python: match 16 requests against 8 routes with Starlette, N rounds (see README.md)."""
import time

from starlette.routing import Match, Route

ROUNDS = 10000

ROUTES = [
    ("GET", "/health"),
    ("GET", "/users"),
    ("POST", "/users"),
    ("GET", "/users/{id}"),
    ("PUT", "/users/{id}"),
    ("GET", "/users/{id}/posts"),
    ("GET", "/users/{id}/posts/{post}"),
    ("GET", "/orgs/{org}/repos/{repo}/issues/{num}"),
]

REQUESTS = [
    ("GET", "/health"),
    ("GET", "/users"),
    ("POST", "/users"),
    ("GET", "/users/42"),
    ("PUT", "/users/42"),
    ("DELETE", "/users/42"),
    ("GET", "/users/7/posts"),
    ("GET", "/users/7/posts/99"),
    ("GET", "/orgs/bendlang/repos/bend/issues/1077"),
    ("GET", "/orgs/bendlang/repos/bend"),
    ("GET", "/missing"),
    ("POST", "/health"),
    ("GET", "/users/alice"),
    ("GET", "/users/alice/posts/first"),
    ("PUT", "/users/bob/posts"),
    ("GET", "/orgs/paymog/repos/bend-kit/issues/73"),
]


def endpoint(request):
    pass


routes = [Route(pat, endpoint, methods=[method]) for method, pat in ROUTES]
scopes = [{"type": "http", "method": method, "path": path} for method, path in REQUESTS]

t0 = time.perf_counter()
h = 0
for _ in range(ROUNDS):
    for scope in scopes:
        # Starlette's Router tries routes in order and takes the first FULL match; PARTIAL means wrong method.
        for i, route in enumerate(routes, 1):
            match, child = route.matches(scope)
            if match is Match.FULL:
                h = (h * 31 + i) & 0xFFFFFFFF
                # path_params keeps the pattern's param order.
                for v in child["path_params"].values():
                    for c in v:
                        h = (h * 31 + ord(c)) & 0xFFFFFFFF
                break
        else:
            h = (h * 31) & 0xFFFFFFFF
ms = (time.perf_counter() - t0) * 1e3
print(f"route\t{ms:.1f}\t{h}")
