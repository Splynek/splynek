# Post-mortem: v1.1 Concierge blank-state regression

**Date identified:** 2026-04-23
**Fixed in:** v1.1.1
**Severity:** P0 — Concierge tab rendered totally blank (sidebar + detail)
on first chip click or first Return-submit, on a shipping v1.1 MAS build.
**Platform scope:** macOS 26 (Tahoe) only. No report on macOS 13/14/15 yet
but the pattern that caused it is cross-version fragile.

## Symptom

1. Launch Splynek. Sidebar + Downloads tab render normally.
2. Click **Concierge** in the sidebar. Empty state with 4 suggestion
   chips + "Using Apple on-device model via Apple Intelligence" footer
   renders correctly.
3. Click any chip (or type into the input bar and press Return).
4. **Within ~50 ms the entire split-view contents disappear.** The
   window stays open, traffic lights + `Concierge` title in the toolbar
   + the Reset button on the right are all still visible. But the
   sidebar column and the detail column are empty white rectangles.
5. State is unrecoverable. Clicking invisible sidebar items does not
   navigate. Model inference completes successfully in the background
   (`os_log` shows the full pipeline through `com.apple.modelmanager` +
   `StringResponseSanitizerRunner: finished successfully`), but its
   result never renders. The user has to quit.

## Why this took several hours to find

Four dead ends, documented here so the next engineer does not repeat them:

1. **We chased Apple Intelligence first.** The bug coincided with the
   v1.1 FoundationModels introduction, so the first hypothesis was that
   `LanguageModelSession.respond(to:)` was doing something wrong. We
   moved the session to a `@MainActor AppleIntelligenceDriver` per the
   WWDC25 session-286 canonical pattern. The bug persisted. *That
   refactor was still worth keeping — it's the correct pattern and it
   eliminated one failure mode — but it wasn't the root cause.*

2. **We chased the `@ViewBuilder` branch swap.** `transcript` returns
   `emptyState` when `aiChat.isEmpty`, else `ScrollViewReader {
   ScrollView { ... } }`. When the chat goes from empty to non-empty,
   SwiftUI must swap branches. We tried a `ZStack` with both branches
   always mounted, toggling opacity. Tab click blanked. We tried
   a single always-mounted `ScrollView` with the empty state inside
   it. Same.

3. **We chased the two-mutations-in-one-tick problem.** `conciergeSend`
   does `aiChat.append(...)` then `aiConciergeThinking = true`. We
   wrapped the second in a `Task { @MainActor in await Task.yield();
   ... }` and even in a 2 ms `Task.sleep`. Didn't help.

4. **We chased `@FocusState`.** Removing the auto-focus onAppear didn't
   help.

The *clinching* diagnostic was to neuter `conciergeSend` to just
`aiChat.append(userMsg); aiChat.append(assistantMsg); return` — no AI
call, no thinking indicator, no task — and **the blank still
reproduced**. That locked the root cause to the view-tree shape, not
to any async path or timing.

## Root cause (three-layer)

All three layers had to be fixed together. Removing any one lets the
bug come back.

### Layer 1 — bottom-up intrinsic-size propagation collapsed the column

SwiftUI lays out bottom-up: child intrinsic sizes bubble up to parents.
`NavigationSplitView` uses the detail view's intrinsic width to decide
how to balance columns against its `min:` / `ideal:` / `max:` widths.

Before the fix, `ConciergeView` had:

```swift
VStack(spacing: 0) {
    ...
    transcript   // @ViewBuilder: emptyState OR ScrollViewReader+ScrollView
    ...
}
.frame(maxWidth: .infinity, maxHeight: .infinity)
```

- When `aiChat.isEmpty`: `emptyState` is a VStack with `Spacer() ... Spacer()`
  and `.frame(maxWidth: .infinity, maxHeight: .infinity)`. Intrinsic
  width reports as .infinity. NavigationSplitView sees a wide detail
  column and keeps the sidebar visible.
- When `!aiChat.isEmpty`: `ScrollView { VStack { bubble } }`. `ScrollView`
  reports the intrinsic width of its **content** — roughly the bubble's
  width, ~200 pt. `NavigationSplitView` then cascades: to honour the
  detail column's `min: 640` with a 200 pt child, it collapses the
  sidebar (moving its width into the detail column) and re-measures.
  Mid-cascade, both columns paint their window-background colour.

The v1.1 code had `.frame(maxWidth: .infinity, maxHeight: .infinity)`
on the outer VStack. That only sets the *accept-up-to-infinity*
hint — SwiftUI still derives the *reported* intrinsic width from the
innermost content.

**The `.frame(maxWidth: .infinity)` on an outer container is NOT
enough to immunise a NavigationSplitView detail pane against
inner-content intrinsic-width collapse on macOS 26.**

### Layer 2 — VM-wide @Published cascade amplified the collapse

`aiChat` was on the root `SplynekViewModel`. `SplynekViewModel` is an
`@ObservedObject` in Sidebar, RootView, and ConciergeView. When
`aiChat.append` fired `objectWillChange`, all three views re-rendered
simultaneously. That concurrent render pass was what turned a
localised detail-column glitch into a window-wide blank.

The moment `aiChat` lives on its own ObservableObject that *only*
ConciergeView observes, the re-render stays scoped. Sidebar and
RootView do not participate in the diff that tips the split-view
over.

### Layer 3 — non-MainActor `LanguageModelSession` invalidated the scene

`LanguageModelSession` is declared `nonisolated Observation.Observable`.
When its tracked properties (e.g. `isResponding`) mutate off the main
actor, SwiftUI cannot narrow the invalidation to the specific leaf —
it invalidates the hosting scene.

Apple's WWDC25 samples (sessions 286, 259, 301) all hold the session
on MainActor. Our v1.1 code held it inside the `AIAssistant` actor's
executor, which is NOT MainActor.

This was not the *dominant* cause (the diagnostic with no AI call
still reproduced blanking), but it was a compounding factor the second
a real AI call landed, and fixing it is the Apple-recommended pattern.

## The fix

Three diffs, all must land together.

**Fix 1 — wrap the body in `GeometryReader` and pin the VStack to the
offered size.** Breaks bottom-up intrinsic-size propagation. See
[ConciergeView.swift:28-58](/Users/pcgm/splynek-pro/Sources/SplynekPro/Views/ConciergeView.swift).

```swift
var body: some View {
    GeometryReader { geo in
        VStack(spacing: 0) { ... }
            .frame(width: geo.size.width, height: geo.size.height)
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .navigationTitle("Concierge")
    .toolbar { ... }
}
```

**Fix 2 — extract `ConciergeState: ObservableObject`.** Scopes the
re-render to ConciergeView. See
[ViewModel.swift:515-545](Sources/SplynekCore/ViewModel.swift).

```swift
@MainActor
final class ConciergeState: ObservableObject {
    @Published var chat: [ConciergeMessage] = []
    @Published var thinking: Bool = false
}

@MainActor
final class SplynekViewModel: ObservableObject {
    let concierge = ConciergeState()   // NOT @Published
    // …
}

struct ConciergeView: View {
    @ObservedObject var vm: SplynekViewModel
    @ObservedObject var conciergeState: SplynekViewModel.ConciergeState
    init(vm: SplynekViewModel) {
        self.vm = vm
        self.conciergeState = vm.concierge
    }
    // …
}
```

**Fix 3 — `@MainActor AppleIntelligenceDriver` holds the session.**
Canonical Apple pattern. See
[AIAssistant.swift:630-705](/Users/pcgm/splynek-pro/Sources/SplynekPro/AIAssistant.swift).

```swift
#if canImport(FoundationModels)
@available(macOS 26, *)
@MainActor
enum AppleIntelligenceDriver {
    static func respond(
        system: String, user: String,
        temperature: Double, maxTokens: Int,
        timeout: TimeInterval
    ) async throws -> String {
        let session = LanguageModelSession(instructions: system)
        // … withThrowingTaskGroup timeout race …
    }
}
#endif
```

The actor's `chatCompletion(...)` dispatcher calls
`try await AppleIntelligenceDriver.respond(...)`, which hops to
MainActor for the session work.

## Rules of thumb for future NavigationSplitView detail panes on macOS 26

1. **Wrap the detail view body in `GeometryReader` and pin children
   to the offered size.** Do not rely on `.frame(maxWidth: .infinity)`
   alone — it's the accept-ceiling, not the report-up value.

2. **Every async / collection @Published that drives detail-pane
   structure belongs in its own ObservableObject.** The larger the
   VM, the more likely two unrelated re-renders will collide on a
   layout change.

3. **`ScrollView` inside a detail pane should always be paired with
   an explicit `.frame(maxWidth: .infinity, maxHeight: .infinity)`
   on the ScrollView itself** (not just on an ancestor). A ScrollView
   with a short-content VStack child will report the child's intrinsic
   width upward.

4. **`@ViewBuilder` branches whose two branches have meaningfully
   different intrinsic sizes are a landmine.** If you must branch,
   make both branches' outer type identical and their `.frame`
   modifiers identical.

5. **Observable types from system frameworks default to nonisolated.**
   Any `Observation.Observable` subclass instantiated off MainActor
   will invalidate the whole hosting scene on property change. Always
   host these on MainActor when a SwiftUI view could read them.

6. **When you can't find the bug in an hour, neuter the suspect
   path to bisect.** Replacing `conciergeSend` with a two-line
   `aiChat.append(...)` ruled out async, actor isolation, and the AI
   call in one test.

## Reproduction recipe for an Apple Radar

1. macOS 26.0+ on Apple Silicon.
2. SwiftUI app with `NavigationSplitView` detail column
   `min: 640, ideal: 880`.
3. Detail view is a VStack whose inner `@ViewBuilder` returns
   `VStack { Spacer() … Spacer() }.frame(maxHeight: .infinity)` when
   a state bool is false, else a `ScrollView` with short content.
4. Mutate the bool from a button's synchronous action inside the
   detail view.
5. Observed: both sidebar and detail pane go empty, toolbar chrome
   survives. Expected: detail swaps content, sidebar unaffected.

Verified NOT required for reproduction:
FoundationModels, @FocusState, `.toolbar` modifier, multiple
@Published mutations per tick, `.onAppear`, StoreKit / IAP.

## Related

- WWDC25 session 286 — *Meet the Foundation Models framework*.
  <https://developer.apple.com/videos/play/wwdc2025/286/>
- WWDC25 session 259 — *Code-along: Bring on-device AI to your app*.
  <https://developer.apple.com/videos/play/wwdc2025/259/>
- WWDC25 session 301 — *Deep dive into the Foundation Models framework*.
  <https://developer.apple.com/videos/play/wwdc2025/301/>
- Earlier related regressions in this codebase:
  v0.43 "ConciergeView shape change collapses sidebar" (fixed by
  keeping the outer VStack identical across Pro / non-Pro branches),
  v0.50.1 "ConciergeView claims full detail column"
  (`.frame(maxWidth: .infinity)` on the outer VStack — the fix that
  worked for the empty-state path but wasn't enough for the
  branch-swap moment).
