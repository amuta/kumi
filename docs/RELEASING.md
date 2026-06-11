# Releasing

Use the release rake tasks from a clean worktree on the branch you intend to publish.

## Prepare a Version

```sh
bundle exec rake release:prepare VERSION=0.0.35
```

This updates:

- `lib/kumi/version.rb`
- `CHANGELOG.md`
- `Gemfile.lock`

The task moves the current `Unreleased` changelog content into a dated release section. It refuses to release an empty changelog unless `ALLOW_EMPTY_CHANGELOG=1` is set.

## Verify and Install Locally

```sh
bundle exec rake release:install
```

This runs the full spec suite, builds `pkg/kumi-<version>.gem`, and installs that gem locally with `--no-document`.

To include the full RuboCop task in release verification:

```sh
STRICT=1 bundle exec rake release:install
```

## Publish to RubyGems

```sh
bundle exec rake release:publish VERSION=0.0.35
```

The publish task requires the explicit `VERSION` to match `lib/kumi/version.rb`, reruns release verification, then runs `gem push`.
It also requires a clean git worktree so the published gem matches committed source. Use `ALLOW_DIRTY=1` only for a deliberate emergency publish.

## Suggested Git Flow

```sh
git diff
bundle exec rake release:install
git add lib/kumi/version.rb CHANGELOG.md Gemfile.lock Rakefile tasks/release.rake docs/RELEASING.md
git commit -m "Release 0.0.35"
bundle exec rake release:publish VERSION=0.0.35
git tag v0.0.35
git push origin HEAD --tags
```
