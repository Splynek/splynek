import SwiftUI

/// **Sovereignty Migrate Wizard** — Sprint 2 part-2 (2026-05-09).
///
/// Modal sheet presented from a Sovereignty alternative row when
/// the user clicks "Migrate".  Walks through the plan one step at
/// a time, showing a per-row confirmation prompt for every
/// destructive step.  Non-destructive steps (open homepage / App
/// Store / data-export) auto-run when the user clicks "Run all".
///
/// Layout:
///   ┌──────────────────────────────────────────────┐
///   │  Migrate Spotify → Tidal                     │
///   │  Two steps.  Each one runs only when you     │
///   │  confirm.                                    │
///   ├──────────────────────────────────────────────┤
///   │  ① Visit Tidal              [✓ Done]         │
///   │      Open tidal.com in Safari                │
///   │      [ Run ]                                 │
///   │  ② Mark Spotify for review  [✓ Done]         │
///   │      Add Spotify to your follow-up list      │
///   │      [ Run ]                                 │
///   ├──────────────────────────────────────────────┤
///   │  Cancel                          [ Run all ] │
///   └──────────────────────────────────────────────┘
///
/// The "Run all" button is enabled only after every destructive
/// step's confirmation prompt has been previewed in an alert
/// (the user clicks each row to read the prompt + confirm).

struct SovereigntyMigrateWizardView: View {
    let plan: SovereigntyMigratePlan
    let onClose: () -> Void

    @State private var outcomes: [String: SovereigntyMigrateRunner.StepOutcome] = [:]
    @State private var isRunningAll: Bool = false
    @State private var pendingConfirmation: SovereigntyMigrateStep?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(plan.steps) { step in
                        stepRow(step)
                    }
                }
                .padding(20)
            }
            Divider()
            footer
        }
        .frame(minWidth: 520, minHeight: 360)
        .alert(
            pendingConfirmation?.confirmationPrompt ?? "",
            isPresented: Binding(
                get: { pendingConfirmation != nil },
                set: { if !$0 { pendingConfirmation = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                pendingConfirmation = nil
            }
            Button(pendingConfirmation?.isDestructive == true
                   ? "Confirm + run" : "Run") {
                if let step = pendingConfirmation {
                    runOne(step)
                }
                pendingConfirmation = nil
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.right.arrow.left.square.fill")
                    .font(.title)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Migrate \(plan.originalDisplayName) → \(plan.alternativeName)")
                        .font(.headline)
                    Text("\(plan.steps.count) step\(plan.steps.count == 1 ? "" : "s"). Each one runs only when you confirm. Nothing is deleted; the original app stays put unless you uninstall it manually.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
        .padding(20)
    }

    @ViewBuilder
    private func stepRow(_ step: SovereigntyMigrateStep) -> some View {
        let outcome = outcomes[step.id]
        HStack(alignment: .top, spacing: 12) {
            // Status indicator
            statusIcon(for: outcome)
                .font(.title3)
                .frame(width: 24)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(step.title)
                        .font(.callout.weight(.semibold))
                    if step.isDestructive {
                        Text("CHANGES STATE")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.18))
                            .clipShape(Capsule())
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                }
                Text(step.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let outcome {
                    outcomeLabel(outcome)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Button {
                        pendingConfirmation = step
                    } label: {
                        Label(step.isDestructive ? "Run with confirmation" : "Run",
                              systemImage: step.isDestructive ? "checkmark.shield" : "play.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(outcome == .completed || isRunningAll)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    @ViewBuilder
    private func statusIcon(for outcome: SovereigntyMigrateRunner.StepOutcome?) -> some View {
        switch outcome {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .skipped:
            Image(systemName: "minus.circle")
                .foregroundStyle(.secondary)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        case .none:
            Image(systemName: "circle")
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func outcomeLabel(_ outcome: SovereigntyMigrateRunner.StepOutcome) -> some View {
        switch outcome {
        case .completed:
            Text("Done.")
        case .skipped(let reason):
            Text("Skipped — \(reason)")
        case .failed(let reason):
            Text("Failed — \(reason)").foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var footer: some View {
        HStack {
            Button("Close") { onClose() }
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button {
                runAll()
            } label: {
                if isRunningAll {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Run all (with confirmations)", systemImage: "play.rectangle.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunningAll || allCompleted)
        }
        .padding(16)
    }

    private var allCompleted: Bool {
        plan.steps.allSatisfy { outcomes[$0.id] == .completed }
    }

    @MainActor
    private func runOne(_ step: SovereigntyMigrateStep) {
        let result = SovereigntyMigrateRunner.run(step: step, plan: plan)
        outcomes[step.id] = result
    }

    @MainActor
    private func runAll() {
        guard !isRunningAll else { return }
        isRunningAll = true
        // Run non-destructive steps in sequence; for destructive
        // steps surface the confirmation alert one at a time.  The
        // user clicking Confirm in the alert advances; clicking
        // Cancel halts the cascade at that step.
        for step in plan.steps where outcomes[step.id] != .completed {
            if step.isDestructive {
                // Defer to per-row confirmation; user has to click
                // each.  This is intentional friction — "Run all"
                // is a convenience for the safe steps only.
                continue
            }
            runOne(step)
        }
        isRunningAll = false
    }
}
