# site

The bend-kit website, live at <https://paymog.github.io/bend-kit/>. It is a Camber application with one route per page. The build calls Camber's in-process `dispatch` for each route and writes each response to a file. No server runs.

| route | page |
|---|---|
| `/` | The package catalog. |
| `/packages/:name` | The README, the laws from `LAWS.bend`, and the tables from `bench/README.md`. |
| `/packages/:name/README.md` | The raw README. |
| `/llms.txt` | The agent index. |

`playground/` is a static page that runs the `markdown` package in the browser. `bend playground/index.html -o` compiles it to JavaScript.

```sh
site/build.sh                                            # writes site/dist for the live URL
site/build.sh /tmp/site http://127.0.0.1:8000 && \
  python3 -m http.server 8000 -d /tmp/site               # local preview
```

The site imports sibling packages by relative path, so it always builds against `main`. It is not a package: `scripts/packages.sh` does not list it, and nothing publishes it to the hub. `.github/workflows/site.yml` builds it on each pull request and deploys it to GitHub Pages on each push to `main`.

The build uses Python 3's standard library to add heading IDs and resolve README links. Links to package READMEs stay on the site. Other relative links point to GitHub. Benchmark headings use a `bench-` prefix to keep their IDs separate from README headings. Run `python3 -m unittest discover -s site -p 'test_*.py'` to check this step.
