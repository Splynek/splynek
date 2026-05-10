import SwiftUI

/// **Concierge sequence preview sheet** — Sprint 2 part-2 (2026-05-09).
///
/// Modal sheet presented when the Concierge proposes a multi-step
/// plan in response to a user prompt.  Mirrors the structure of
/// `SovereigntyMigrateWizardView`: per-step rows with status pill,
/// confirmation prompt for mutating steps, "Run" footer button.
///
/// **Wiring** (Sprint 3 work):
///   - `splynek-pro`'s ConciergeBridge emits a `ConciergeSequence`
///     in response to a user prompt.
///   - ConciergeView (in pro) presents this preview sheet.
///   - User taps Run → calls `ConciergeSequenceRunner.run(...)`
///     with a confirmation callback that pops the per-step alert
///     pre-baked here.
///
/// This commit ships the **view + state machine** so the runner is
/// fully exercisable end-to-end.  The free-tier ConciergeView still
/// only renders informational responses; sequence proposals are a
/// Pro path that lives in splynek-pro.

struct ConciergeSequencePreviewView: View {
    let sequence: ConciergeSequence
    let runner: ConciergeSequenceRunner
    let onClose: () -> Void

    @State private var outcomes: [String: ConciergeSequenceRunner.StepResult] = [:]
    @State private var isRunning: Bool = false
    @State private var pendingConfirmation: ConciergeSequenceStep?
    @State private var confirmationContinuation: CheckedContinuation<Bool, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(sequence.steps) { step in
                        stepRow(step)
                    }
                }
                .padding(20)
            }
            Divider()
            footer
        }
        .frame(minWidth: 540, minHeight: 380)
        .alert(
            pendingConfirmation?.summary ?? "",
            isPresented: Binding(
                get: { pendingConfirmation != nil },
                set: { if !$0 { resolveConfirmation(false) } }
            )
        ) {
            Button("Cancel", role: .cancel) { resolveConfirmation(false) }
            Button("Confirm + run") { resolveConfirmation(true) }
        } message: {
            if let step = pendingConfirmation {
                Text(messageFor(step))
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.title)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Concierge proposal")
                        .font(.headline)
                    Text("\"\(sequence.originPrompt)\" → \(sequence.steps.count) step\(sequence.steps.count == 1 ? "" : "s"), \(sequence.mutatingStepCount) require confirmation.")
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
    private func stepRow(_ step: ConciergeSequenceStep) -> some View {
        let result = outcomes[step.id]
        HStack(alignment: .top, spacing: 12) {
            statusIcon(for: result)
                .font(.title3)
                .frame(width: 24)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(displayName(for: step.kind))
                        .font(.callout.weight(.semibold))
                    if step.kind.isMutating {
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
                if let result {
                    resultLabel(result)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
    private var footer: some View {
        HStack {
            Button("Close") { onClose() }
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button {
                Task { await runAll() }
            } label: {
                if isRunning {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Run sequence", systemImage: "play.rectangle.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunning || allCompleted)
        }
        .padding(16)
    }

    private var allCompleted: Bool {
        sequence.steps.allSatisfy {
            if case .completed = outcomes[$0.id] { return true }
            return false
        }
    }

    // MARK: Run

    private func runAll() async {
        guard !isRunning else { return }
        isRunning = true
        let result = await runner.run(sequence) { step in
            await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                Task { @MainActor in
                    self.confirmationContinuation = cont
                    self.pendingConfirmation = step
                }
            }
        }
        for outcome in result {
            outcomes[outcome.stepID] = outcome.result
        }
        isRunning = false
    }

    private func resolveConfirmation(_ ok: Bool) {
        let cont = confirmationContinuation
        confirmationContinuation = nil
        pendingConfirmation = nil
        cont?.resume(returning: ok)
    }

    // MARK: Helpers

    @ViewBuilder
    private func statusIcon(for result: ConciergeSequenceRunner.StepResult?) -> some View {
        switch result {
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
    private func resultLabel(_ result: ConciergeSequenceRunner.StepResult) -> some View {
        switch result {
        case .completed(let output):
            Text(output)
        case .skipped(let reason):
            Text("Skipped — \(reason)")
        case .failed(let reason):
            Text("Failed — \(reason)").foregroundStyle(.red)
        }
    }

    private func displayName(for kind: ConciergeStepKind) -> String {
        switch kind {
        case .lookupSovereignty:  return "Look up Sovereignty entry"
        case .lookupTrust:        return "Look up Trust profile"
        case .sovereigntyScan:    return "Re-scan installed apps"
        case .getProgress:        return "Check current downloads"
        case .listHistory:        return "Read recent download history"
        case .downloadURL:        return "Start a new download"
        case .queueURL:           return "Queue a URL for later"
        case .cancelAll:          return "Cancel all downloads"
        }
    }

    private func messageFor(_ step: ConciergeSequenceStep) -> String {
        switch step.kind {
        case .downloadURL:
            return "Start downloading the URL the Concierge picked. Splynek will fetch it across all interfaces and verify the SHA-256 (when known)."
        case .queueURL:
            return "Add the URL to Splynek's queue. The download starts when its turn comes up."
        case .cancelAll:
            return "Stop every running download immediately. In-flight bytes are discarded; queued items stay queued."
        default:
            return "Run this step."
        }
    }
}
