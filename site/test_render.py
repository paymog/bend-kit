import unittest

from render import PackagePage, REPO, fragment


class ReadmeNavigation(unittest.TestCase):
    def render(self, text):
        page = PackagePage("retry", "https://example.test/bend-kit", {"retry", "http"})
        page.feed(text)
        page.close()
        return "".join(page.out)

    def test_headings_and_fragments(self):
        result = self.render('''<section class="readme">
<h2>Circuit <em>breaker</em></h2><a href="#circuit-breaker">Jump</a>
<h2>Circuit breaker</h2><h2>Circuit breaker-1</h2>
<h3>Élan &amp; <code>API</code>!</h3><pre>&lt;h2&gt;Code&lt;/h2&gt;</pre>
</section>''')
        for heading in ('circuit-breaker', 'circuit-breaker-1', 'circuit-breaker-1-1', 'élan--api'):
            self.assertIn('id="' + heading + '"', result)
        self.assertIn('href="#circuit-breaker"', result)
        self.assertIn('&lt;h2&gt;Code&lt;/h2&gt;', result)

    def test_package_and_source_links(self):
        result = self.render('''<section class="readme">
<a href="../http/README.md#requests">HTTP</a><a href="../http">HTTP</a>
<a href="README.md#checks">Self</a><a href="../missing/README.md">Missing</a>
<a href="check.bend?raw=1&amp;x=2">Source</a>
<a href="https://example.org/README.md">External</a>
<a href="mailto:a@example.org">Mail</a><a href="/root">Root</a>
<img src="assets/chart.svg" alt="chart" />
</section>''')
        for href in (
            'https://example.test/bend-kit/packages/http/#requests',
            'https://example.test/bend-kit/packages/http/',
            'https://example.test/bend-kit/packages/retry/#checks',
            REPO + 'missing/README.md', REPO + 'retry/check.bend?raw=1&amp;x=2',
            'https://example.org/README.md', 'mailto:a@example.org', '/root',
        ):
            self.assertIn('href="' + href + '"', result)
        self.assertIn('src="https://raw.githubusercontent.com/paymog/bend-kit/main/retry/assets/chart.svg"', result)

    def test_benchmark_context(self):
        result = self.render('''<section class="readme"><h2>Checks</h2>
<a href="bench/README.md#checks">Bench</a><a href="bench/README.md">Bench</a></section>
<section class="bench"><h2>Checks</h2><a href="#checks">Jump</a>
<a href="../../http/README.md">HTTP</a><a href="main.c">Code</a></section>''')
        for value in ('id="checks"', 'id="benchmarks"', 'id="bench-checks"',
                      'href="#bench-checks"', 'href="#benchmarks"',
                      'href="https://example.test/bend-kit/packages/http/"',
                      'href="' + REPO + 'retry/bench/main.c"'):
            self.assertIn(value, result)

    def test_surrounding_html_stays_intact(self):
        source = '<!doctype html><!-- test --><nav><a href="#top">Top</a></nav>'
        self.assertEqual(self.render(source), source)

    def test_document_navigation(self):
        page = PackagePage("", "https://example.test/bend-kit", {"bytes"})
        page.feed('''<section class="readme"><h1>Roadmap</h1>
<a href="README.md">Catalog</a><a href="CHANGELOG.md#unreleased">Changes</a>
<a href="ROADMAP.md">Plans</a><a href="bytes/README.md">Bytes</a>
<a href="scripts/check.sh">Check</a></section>''')
        page.close()
        result = "".join(page.out)
        for href in ("https://example.test/bend-kit/",
                     "https://example.test/bend-kit/changelog/#unreleased",
                     "https://example.test/bend-kit/roadmap/",
                     "https://example.test/bend-kit/packages/bytes/",
                     REPO + "scripts/check.sh"):
            self.assertIn('href="' + href + '"', result)
        self.assertIn('id="roadmap"', result)

    def test_shared_fragments_match_page_navigation(self):
        readme = '<h2>Checks</h2><a href="../http/README.md">HTTP</a>'
        bench = '<h2>Benchmarks</h2><a href="#benchmarks">Jump</a>'
        whole = self.render('<section class="readme">' + readme + '</section><section class="bench"><h2>Benchmarks</h2>' + bench + '</section>')
        prepared = '<section class="readme">' + fragment(readme, "retry", "https://example.test/bend-kit", "readme", {"http"}) + '</section><section class="bench" id="benchmarks"><h2 id="bench-benchmarks">Benchmarks</h2>' + fragment(bench, "retry", "https://example.test/bend-kit", "bench", {"http"}) + '</section>'
        self.assertEqual(prepared, whole)


if __name__ == "__main__":
    unittest.main()
