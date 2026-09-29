// Router benchmark: match 16 requests against 8 routes with r3, N rounds (see README.md).
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

#include <r3.h>

#define ROUNDS 10000

static const struct { int method; const char *pat; } ROUTES[] = {
    {METHOD_GET, "/health"},
    {METHOD_GET, "/users"},
    {METHOD_POST, "/users"},
    {METHOD_GET, "/users/{id}"},
    {METHOD_PUT, "/users/{id}"},
    {METHOD_GET, "/users/{id}/posts"},
    {METHOD_GET, "/users/{id}/posts/{post}"},
    {METHOD_GET, "/orgs/{org}/repos/{repo}/issues/{num}"},
};

static const struct { int method; const char *path; } REQUESTS[] = {
    {METHOD_GET, "/health"},
    {METHOD_GET, "/users"},
    {METHOD_POST, "/users"},
    {METHOD_GET, "/users/42"},
    {METHOD_PUT, "/users/42"},
    {METHOD_DELETE, "/users/42"},
    {METHOD_GET, "/users/7/posts"},
    {METHOD_GET, "/users/7/posts/99"},
    {METHOD_GET, "/orgs/bendlang/repos/bend/issues/1077"},
    {METHOD_GET, "/orgs/bendlang/repos/bend"},
    {METHOD_GET, "/missing"},
    {METHOD_POST, "/health"},
    {METHOD_GET, "/users/alice"},
    {METHOD_GET, "/users/alice/posts/first"},
    {METHOD_PUT, "/users/bob/posts"},
    {METHOD_GET, "/orgs/paymog/repos/bend-kit/issues/73"},
};

#define LEN(a) (sizeof(a) / sizeof((a)[0]))

static uint32_t mix(uint32_t h, uint32_t x) { return h * 31 + x; }

int main(void) {
    node *tree = r3_tree_create(10);
    for (size_t i = 0; i < LEN(ROUTES); i++)
        r3_tree_insert_route(tree, ROUTES[i].method, ROUTES[i].pat, (void *)(uintptr_t)(i + 1));
    char *err = NULL;
    if (r3_tree_compile(tree, &err) != 0) {
        fprintf(stderr, "r3_tree_compile: %s\n", err);
        return 1;
    }

    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    uint32_t h = 0;
    for (int n = 0; n < ROUNDS; n++) {
        for (size_t r = 0; r < LEN(REQUESTS); r++) {
            match_entry *e = match_entry_create(REQUESTS[r].path);
            e->request_method = REQUESTS[r].method;
            route *m = r3_tree_match_route(tree, e);
            if (!m) {
                h = mix(h, 0);
            } else {
                h = mix(h, (uint32_t)(uintptr_t)m->data);
                // r3 captures slugs in path order, which is the route's param order.
                for (int k = 0; k < e->vars->len; k++)
                    for (const char *c = e->vars->tokens[k]; *c; c++) h = mix(h, (unsigned char)*c);
            }
            match_entry_free(e);
        }
    }
    clock_gettime(CLOCK_MONOTONIC, &t1);
    double ms = (t1.tv_sec - t0.tv_sec) * 1e3 + (t1.tv_nsec - t0.tv_nsec) / 1e6;
    printf("route\t%.1f\t%u\n", ms, h);
    r3_tree_free(tree);
    return 0;
}
