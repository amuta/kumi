# Documentation Portal

The public documentation portal lives in a separate repo,
[`amuta/kumi-docs`](https://github.com/amuta/kumi-docs), and is published to
GitHub Pages with [MkDocs Material](https://squidfunk.github.io/mkdocs-material/).

Most pages there are hand-written. A few are **generated from this repo** and
must never be edited by hand in kumi-docs:

- the **function reference**, from `data/functions` + `data/kernels`, and
- the **worked pipeline transformations** and **examples**, rendered by running
  `bin/kumi pp` over a curated set of `golden/` schemas.

## Regenerate locally

```bash
bundle exec rake docs:portal
```

This writes everything under `tmp/docs-artifacts/` (gitignored):

```
tmp/docs-artifacts/
  reference/functions.md
  reference/pipeline/<schema>/<stage>.md
  examples/<name>.md
```

The teaching schemas and the stages rendered for each are configured at the top
of [`tasks/docs_portal.rake`](../tasks/docs_portal.rake) (`TEACHING_SCHEMAS`,
`STAGES`).

## Publishing

`.github/workflows/docs.yml` runs `rake docs:portal` on pushes to `main` that
touch functions, kernels, goldens, or `lib/`, then copies the artifacts into
kumi-docs under `docs/reference/generated/` and `docs/examples/` and pushes.
It requires a `KUMI_DOCS_TOKEN` repo secret with push access to kumi-docs.
The kumi-docs `pages.yml` workflow then builds and deploys the site.
