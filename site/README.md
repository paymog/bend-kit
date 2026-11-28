# site

The bend-kit website is a Camber application with one route per page. `server.bend` serves those routes through Camber's native HTTP transport. The build calls the same application through in-process `dispatch` and writes each response to a file. The target live URL is <https://bend-kit.paymahn.workers.dev/>. GitHub Pages remains a static mirror.

| route | page |
|---|---|
| `/` | The package catalog. |
| `/getting-started` | Install Bend, import a hub package, and run a check. |
| `/changelog` | The root `CHANGELOG.md`. |
| `/roadmap` | The root `ROADMAP.md`. |
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

The shared loader uses Python 3's standard library to add heading IDs and resolve README links before it builds the application. This runs at startup, not on each request. Both entry points render the same prepared Markdown and templates. Links to package READMEs stay on the site. Other relative links point to GitHub. Benchmark headings use a `bench-` prefix to keep their IDs separate from README headings. Run `python3 -m unittest discover -s site -p 'test_*.py'` to check this step.

The three documentation pages use the same Markdown renderer and layout as the package pages. Edit `site/getting-started.md` for the guide. The changelog and roadmap read the root files at build time. `site/build.sh` checks the generated documentation pages before it finishes.

## Native server

Run these commands from the repository root:

```sh
site/build.sh && \
  bend site/server.bend -o site/out/server && \
  site/out/server +RTS --threads 1 --gpu off -RTS 8080 . https://bend-kit.paymahn.workers.dev $(scripts/packages.sh)
```

The server binds all interfaces. In a container, expose port 8080 only through the HTTPS gateway. It registers only the page routes, the style sheet, and the files in the built playground directory. It does not map arbitrary request paths to files. Assets have a 32 MiB limit. Successful responses use their media type and `Cache-Control: public, max-age=300`.

With the server running, compare every page, raw README, and asset with the final static files. The check also covers trailing slashes, HEAD, missing paths, and unsupported methods:

```sh
python3 site/live_check.py site/dist http://127.0.0.1:8080
```

## Cloudflare deployment

The dedicated `bend-kit` Worker forwards HTTPS requests to one native container. The container runs as an unprivileged user without outbound Internet access. It sleeps after ten idle minutes. The next request starts it again. The gateway does not render pages.

The Dockerfile uses the same checksum-pinned Bend 2.0.40 installer as CI. Build the image on Linux x86-64. The compiler's bundled Bun can crash when an ARM host emulates x86 without AVX. To use a native GitHub runner instead:

```sh
gh workflow run site.yml --ref YOUR_BRANCH -f build-container=true
```

After that run passes, download its image, load it, and deploy with the personal Cloudflare login:

```sh
gh run download RUN_ID -n bend-kit-site-image -D /tmp/bend-kit-image && \
  docker load -i /tmp/bend-kit-image/bend-kit-site.tar.gz && \
  cd site/deploy && \
  npm ci --ignore-scripts && \
  npx wrangler containers push bend-kit-site:ci && \
  npx wrangler deploy
```

The container registry tag is `bend-kit-site:ci`. Deploy only an image from the commit that passed CI. No Cloudflare credential is stored in the repository or GitHub Actions. GitHub Pages remains available while this manual deployment runs.

After the container becomes ready, run the same parity check against HTTPS. Build the comparison files from the same commit and base URL as the image:

```sh
python3 site/live_check.py site/dist https://bend-kit.paymahn.workers.dev
```
