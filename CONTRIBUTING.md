# Contributing to Splynek

Short version: file an issue first, keep the PR tight, run the tests.

## What Splynek is

Pure-Swift native macOS download manager. Swift Package Manager,
no third-party Swift deps, no Xcode-only features. See
[HANDOFF.md](HANDOFF.md) for the load-bearing architecture
invariants — don't break them without discussion.

## Getting set up

```sh
git clone <this repo>
cd splynek
./Scripts/build.sh        # produces build/Splynek.app
open build/Splynek.app    # run it
swift run splynek-test    # 56 tests, should all pass green
swift run splynek-cli version   # CLI talking to a running app
```

Swift 5.9+ via Command Line Tools. Xcode is not required. macOS 13+.

## Proposing a change

1. **File an issue first.** Describe the problem, not the solution.
   A conversation in an issue is much cheaper than a conversation
   in a PR.
2. **Small PRs.** One logical change per PR. "Add Feature X + fix
   Y + rename Z" is three PRs.
3. **Explain the *why*, not the *what*.** The diff shows the what.
   The PR description should answer: what problem does this solve,
   what did you consider and reject, what are the tradeoffs.

## Architecture invariants — do not break without discussion

Copy-pasted from `HANDOFF.md` for prominence:

- **Interface binding.** Every outbound data socket is pinned to
  an `NWInterface` via `NWParameters.requiredInterface`. This is
  the core of what Splynek IS. Don't add network code that bypasses
  it.
- **Zero third-party Swift dependencies.** `Package.swift` must
  stay empty of external products. BitTorrent, DHT, DoH, Metalink
  XML, the test harness — all hand-rolled against Foundation,
  Network.framework, CryptoKit.
- **ViewModel owns shared mutable state.** `SplynekViewModel` is
  the `@MainActor ObservableObject` that holds everything. Views
  bind to it; engines publish to it. Don't introduce parallel
  state stores.
- **`splynek://` is the one ingress.** Drag-drop, Shortcuts,
  browser extensions, menu-bar popover, Chrome extension, CLI,
  web dashboard — they all construct `splynek://` URLs or call
  the REST API. Don't add parallel ingress paths.

## Code style

- **Comments explain *why*, not *what*.** Well-named identifiers
  are the *what*. If you find yourself writing a comment that
  restates the next line of code, delete the comment and find
  a better name.
- **Default to no comments.** Only add one where the *why* is
  non-obvious: a hidden constraint, a subtle invariant, a
  workaround for a specific bug.
- **Never write multi-line doc comments.** One short line max.
- **Swift concurrency.** `@MainActor` isolation is consistent;
  cross-actor work happens via `Task { @MainActor in … }` or
  explicit actor hops. Don't introduce captured-var mutations or
  non-Sendable closures.
- **Warnings treated as errors.** Aim for zero build warnings.

## Testing

Run `swift run splynek-test`. All 56+ tests must pass. Add tests
when you add code that does something non-trivial. Use the
existing harness in `Tests/SplynekTests/Harness.swift` — no XCTest,
no Swift Testing; we're Xcode-optional.

## What we won't accept

- Dependencies on third-party Swift packages.
- Code that sends telemetry or analytics anywhere.
- PRs that require an Apple Developer account to test / build.
- Features behind paywall flags lifted directly into the OSS
  codebase — Pro-tier features live in their own branch if they
  exist at all.
- Changes that break the ad-hoc signed build flow.

## Reporting security issues

Don't file publicly. Email the maintainers first so a fix can
land before disclosure. See [SECURITY.md](SECURITY.md) for the
threat model.

## License

By contributing, you agree that your contributions will be
licensed under the MIT Licence (`LICENSE`).
