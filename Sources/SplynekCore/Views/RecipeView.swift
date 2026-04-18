import SwiftUI

/// Agentic download recipes (v0.42). The user types a goal — "set up
/// my Mac for iOS dev" — and the local LLM proposes a list of
/// verifiable downloads. User reviews, unchecks items they don't
/// want, clicks Queue. Splynek executes the batch through the
/// existing queue + multi-interface + schedule plumbing.
///
/// UX principles:
///   - **Human-in-the-loop by default.** The LLM proposes; the user
///     disposes. Every item is editable/unselectable before execution.
///   - **Trust surface.** Every item shows: name, URL (copyable),
///     homepage link, confidence pill, rationale. Low-confidence
///     items (<0.7) render with a warning stripe so the user knows
///     to double-check.
///   - **No auto-queue, ever.** The user clicks Queue. The LLM
///     doesn't start downloads on its own — that would be where
///     "agentic" crosses into "creepy."
///   - **Pro-gated.** Aligns with MONETIZATION.md — AI Concierge +
///     Recipes are the core Pro wedge.
struct RecipeView: View {
    @ObservedObject var vm: SplynekViewModel
    @State private var goal: String = ""
    @FocusState private var goalFocused: Bool

    var body: some View {
        // QA P1 root-cause (v0.43): the Pro gate lives in the
        // sidebar — RecipeView only ever renders when the user is
        // Pro. The in-view Pro-gate branch was removed because it
        // triggered a SwiftUI NavigationSplitView layout bug on
        // macOS 14. See Sidebar.swift for the gate comment.
        ScrollView {
            VStack(spacing: 16) {
                PageHeader(
                    systemImage: "list.star",
                    title: "Recipes",
                    subtitle: "Type a goal. Your local LLM proposes a verified batch of downloads. You review, edit, and queue in one click."
                )
                if !vm.aiAvailable {
                    aiMissingCard
                } else {
                    goalCard
                    if vm.recipeGenerating {
                        generatingCard
                    } else if let err = vm.recipeError {
                        errorCard(err)
                    }
                    if let recipe = vm.currentRecipe {
                        recipeCard(recipe)
                    }
                    if !vm.recipeHistory.isEmpty {
                        historyCard
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 820)
        }
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Recipes")
        .onChange(of: vm.currentRecipe?.id) { _ in
            // QA P2 #3: clear goal once recipe arrives.
            if vm.currentRecipe != nil { goal = "" }
        }
    }

    private var aiMissingCard: some View {
        TitledCard(
            title: "Local LLM required",
            systemImage: "exclamationmark.bubble",
            accessory: AnyView(StatusPill(text: "NO OLLAMA", style: .warning))
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Recipes run entirely on your own machine via Ollama — no cloud, no telemetry, no data leaves the Mac.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Install Ollama from ollama.com and pull a small model:")
                    .font(.callout).foregroundStyle(.secondary)
                Text("ollama pull llama3.2:3b")
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.06))
                    )
                    .textSelection(.enabled)
                HStack {
                    Button {
                        Task { await vm.refreshAIStatus() }
                    } label: {
                        Label("Retry detection", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    if let url = URL(string: "https://ollama.com") {
                        Link(destination: url) {
                            Label("ollama.com", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.bordered)
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: Goal card

    private var goalCard: some View {
        TitledCard(title: "Goal", systemImage: "wand.and.stars") {
            VStack(alignment: .leading, spacing: 10) {
                TextEditor(text: $goal)
                    .font(.system(.body, design: .default))
                    .focused($goalFocused)
                    .frame(minHeight: 56, maxHeight: 80)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
                    .overlay(alignment: .topLeading) {
                        if goal.isEmpty {
                            Text("e.g. set up my Mac for iOS development")
                                .font(.body).foregroundStyle(.secondary)
                                .padding(12)
                                .allowsHitTesting(false)
                        }
                    }
                HStack(spacing: 10) {
                    suggestionChip("Set up my Mac for iOS development")
                    suggestionChip("Everything I need to self-host Linux on a Mini")
                    suggestionChip("Latest Ubuntu desktop + VS Code + Docker")
                }
                HStack {
                    Text("Runs on \(vm.aiModel ?? "local LLM"). Typically 10–60 s.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        vm.generateRecipe(for: goal)
                    } label: {
                        Label("Generate recipe", systemImage: "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(goal.trimmingCharacters(in: .whitespaces).isEmpty
                              || vm.recipeGenerating)
                    .keyboardShortcut(.return, modifiers: [.command])
                }
            }
        }
    }

    private func suggestionChip(_ text: String) -> some View {
        Button { goal = text; goalFocused = true } label: {
            Text(text)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous).fill(Color.primary.opacity(0.06))
                )
                .overlay(
                    Capsule(style: .continuous).strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: Generating / error

    private var generatingCard: some View {
        TitledCard(
            title: "Thinking…",
            systemImage: "wand.and.stars",
            accessory: AnyView(ProgressView().controlSize(.small))
        ) {
            Text("The local LLM is drafting your recipe. This usually takes 10–60 s on Apple Silicon.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private func errorCard(_ message: String) -> some View {
        TitledCard(
            title: "Recipe generation failed",
            systemImage: "exclamationmark.triangle",
            accessory: AnyView(StatusPill(text: "ERROR", style: .danger))
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(message).font(.callout).foregroundStyle(.red)
                    .textSelection(.enabled)
                Text("Try rephrasing the goal, or pull a larger model. Small models under 3B parameters sometimes struggle with structured JSON output.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Recipe card

    private func recipeCard(_ recipe: DownloadRecipe) -> some View {
        let selectedCount = recipe.items.filter(\.selected).count
        return TitledCard(
            title: recipe.title,
            systemImage: "list.bullet.clipboard.fill",
            accessory: AnyView(StatusPill(
                text: "\(selectedCount)/\(recipe.items.count) SELECTED",
                style: selectedCount > 0 ? .success : .neutral
            ))
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Proposed by \(recipe.modelUsed). Review each item — tap to open its homepage in a browser — then queue what you want.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 6) {
                    ForEach(recipe.items) { item in
                        RecipeRow(item: item) { vm.toggleRecipeItem(id: item.id) }
                    }
                }

                Divider().opacity(0.3)

                HStack(spacing: 10) {
                    Button(role: .destructive) {
                        vm.discardCurrentRecipe()
                    } label: {
                        Label("Discard", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    if selectedCount < recipe.items.count {
                        Text("\(recipe.items.count - selectedCount) unchecked")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button {
                        vm.queueCurrentRecipe()
                    } label: {
                        Label("Queue \(selectedCount) download\(selectedCount == 1 ? "" : "s")",
                              systemImage: "tray.and.arrow.down.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedCount == 0)
                    .keyboardShortcut("q", modifiers: [.command, .shift])
                }
            }
        }
    }

    // MARK: History

    private var historyCard: some View {
        TitledCard(title: "Recent recipes", systemImage: "clock.arrow.circlepath") {
            VStack(spacing: 4) {
                ForEach(vm.recipeHistory.prefix(10)) { recipe in
                    Button {
                        vm.reopenRecipe(recipe)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "list.bullet.clipboard")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(recipe.title)
                                    .font(.system(.callout, weight: .semibold))
                                Text("\(recipe.items.count) items · \(recipe.modelUsed) · \(relative(recipe.generatedAt))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.backward")
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.03))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func relative(_ date: Date) -> String { formatRelative(date) }
}

// MARK: - Recipe row

private struct RecipeRow: View {
    let item: RecipeItem
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: item.selected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundStyle(item.selected ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(.headline, design: .rounded))
                    confidencePill
                    if let size = item.sizeHint, !size.isEmpty {
                        Text(size)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let urlsha = item.sha256 {
                        Text("sha256: \(String(urlsha.prefix(8)))…")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .help(urlsha)
                    }
                }

                Text(item.rationale)
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    if let url = URL(string: item.url) {
                        Label(item.url, systemImage: "arrow.down.circle")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                            .textSelection(.enabled)
                            .onTapGesture {
                                NSWorkspace.shared.open(url)
                            }
                    }
                    if let hp = item.homepage, let url = URL(string: hp) {
                        Link(destination: url) {
                            Label("Homepage", systemImage: "safari")
                                .font(.caption)
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(item.confidence < 0.7
                      ? Color.orange.opacity(0.05)
                      : Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    item.confidence < 0.7 ? Color.orange.opacity(0.3) : Color.primary.opacity(0.08),
                    lineWidth: 0.5
                )
        )
        .opacity(item.selected ? 1.0 : 0.55)
    }

    @ViewBuilder private var confidencePill: some View {
        let pct = Int((item.confidence * 100).rounded())
        let style: StatusPill.Style =
            item.confidence >= 0.85 ? .success
            : item.confidence >= 0.7 ? .info
            : .warning
        StatusPill(text: "\(pct)%", style: style)
    }
}
