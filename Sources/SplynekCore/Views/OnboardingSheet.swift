import SwiftUI
import AppKit

/// v1.6.1: first-launch onboarding sheet.
///
/// Splynek used to land users straight on Downloads with no
/// orientation — fine for the geek cohort that sought it out, brutal
/// for the EU-policy-curious user who wandered in from a Show HN
/// link.  Three short steps set the tone:
///
///   1. **Welcome** — what Splynek does in one sentence + the four
///      things that separate it from a generic download manager.
///   2. **Output folder** — let the user confirm or pick a location.
///      Defaults to `~/Downloads`; we only show the picker if the
///      default is unreachable.  A non-decision becomes a deliberate
///      consent moment.
///   3. **Optional audit** — single button that fires the Sovereignty
///      + Trust scan in one go.  Sets the "this is what we mean by
///      privacy-first" tone immediately rather than burying it three
///      tabs deep.
///
/// Shown once, then `vm.hasCompletedOnboarding` flips and the sheet
/// never appears again.  Skippable at any step — we'd rather a user
/// dismiss than feel trapped.
struct OnboardingSheet: View {
    @ObservedObject var vm: SplynekViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .welcome
    @State private var didStartScan = false

    enum Step: Int, CaseIterable {
        case welcome, outputFolder, audit
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar — Skip on the right, page indicator centered.
            HStack {
                Spacer()
                stepDots
                Spacer()
                Button("Skip") { complete() }
                    .buttonStyle(.splynekHover)
                    .foregroundStyle(.secondary)
                    .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Body — switch to whichever step we're on.
            Group {
                switch step {
                case .welcome:      welcomeStep
                case .outputFolder: outputFolderStep
                case .audit:        auditStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Footer — Back + primary action.
            HStack {
                if step != .welcome {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            step = Step(rawValue: step.rawValue - 1) ?? .welcome
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                } else {
                    // Visual placeholder so the primary action stays
                    // anchored to the trailing edge regardless of step.
                    Color.clear.frame(width: 0)
                }
                Spacer()
                primaryButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
        }
        .frame(width: 620, height: 540)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Step indicator

    private var stepDots: some View {
        HStack(spacing: 8) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Circle()
                    .fill(s == step ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
                    .accessibilityLabel("Step \(s.rawValue + 1) of 3")
                    .accessibilityAddTraits(s == step ? [.isSelected] : [])
            }
        }
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 18) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.accentColor, .purple],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .padding(.top, 24)

            VStack(spacing: 8) {
                Text("Welcome to Splynek")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("A download manager that pools every network connection your Mac has — Wi-Fi, Ethernet, your iPhone's tether, all at once.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }

            VStack(alignment: .leading, spacing: 12) {
                bullet("Faster", "Aggregates throughput across every network you're connected to.", "bolt.fill")
                bullet("Honest", "Every download verified against the publisher's checksum.", "checkmark.shield.fill")
                bullet("Private", "Nothing leaves your Mac. No account. No telemetry.", "lock.shield.fill")
                bullet("Sovereign", "See where the apps on your Mac come from, and what regulators say about them.", "shield.lefthalf.filled")
            }
            .frame(maxWidth: 480)
            .padding(.top, 6)

            Spacer()
        }
        .padding(.horizontal, 28)
    }

    @ViewBuilder
    private func bullet(_ title: String, _ body: String, _ icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .font(.title3)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Output folder

    private var outputFolderStep: some View {
        VStack(spacing: 18) {
            Image(systemName: "folder.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .cyan],
                                   startPoint: .top, endPoint: .bottom)
                )
                .padding(.top, 24)

            VStack(spacing: 8) {
                Text("Where should downloads go?")
                    .font(.system(.title, design: .rounded, weight: .bold))
                Text("Splynek will save files here. You can change this later in Settings — but picking once now means you'll always know where things land.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }

            // Current selection card — shows the path + a Change button.
            VStack(alignment: .leading, spacing: 10) {
                Text("Selected folder")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Image(systemName: "folder")
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.outputDirectory.lastPathComponent)
                            .font(.callout.weight(.medium))
                        Text(vm.outputDirectory.path)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button("Change…") { pickFolder() }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
            }
            .frame(maxWidth: 460)
            .padding(.top, 8)

            Text("Tip: many users keep ~/Downloads. Splynek doesn't move files there — it goes straight to whatever you pick.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
                .padding(.top, 4)

            Spacer()
        }
        .padding(.horizontal, 28)
    }

    /// NSOpenPanel folder picker.  Confirms the selection on the VM
    /// (which persists to UserDefaults via the existing didSet).
    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose a download folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = vm.outputDirectory
        if panel.runModal() == .OK, let url = panel.url {
            vm.outputDirectory = url
        }
    }

    // MARK: - Audit

    private var auditStep: some View {
        VStack(spacing: 18) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .pink],
                                   startPoint: .top, endPoint: .bottom)
                )
                .padding(.top, 24)

            VStack(spacing: 8) {
                Text("Run a quick audit?")
                    .font(.system(.title, design: .rounded, weight: .bold))
                Text("Splynek can scan the apps on your Mac and tell you where each one is controlled from, plus what public records say about its privacy and security. Local-only — nothing leaves your device.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }

            VStack(alignment: .leading, spacing: 10) {
                privacyBullet("Reads only the bundle list — never opens app contents")
                privacyBullet("Stays on-device — no network calls, ever")
                privacyBullet("Takes about 5 seconds")
            }
            .frame(maxWidth: 460)
            .padding(.top, 6)

            Spacer()

            if didStartScan {
                Label("Scan started — results appear in Sovereignty + Trust tabs.",
                      systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
                    .padding(.bottom, 10)
            }
        }
        .padding(.horizontal, 28)
    }

    @ViewBuilder
    private func privacyBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield")
                .foregroundStyle(.tint)
            Text(text).font(.callout)
            Spacer()
        }
    }

    // MARK: - Primary action button (per-step)

    @ViewBuilder
    private var primaryButton: some View {
        switch step {
        case .welcome:
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { step = .outputFolder }
            } label: {
                Label("Continue", systemImage: "arrow.right")
                    .frame(minWidth: 140)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .outputFolder:
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { step = .audit }
            } label: {
                Label("Continue", systemImage: "arrow.right")
                    .frame(minWidth: 140)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .audit:
            HStack(spacing: 10) {
                if !didStartScan {
                    Button {
                        runAudit()
                    } label: {
                        Label("Run audit + finish", systemImage: "magnifyingglass")
                            .frame(minWidth: 200)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    Button("Maybe later") { complete() }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                } else {
                    Button {
                        complete()
                    } label: {
                        Label("Get started", systemImage: "checkmark")
                            .frame(minWidth: 180)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
    }

    // MARK: - Lifecycle

    /// Kick off the Sovereignty scan.  Each tab owns its own
    /// `SovereigntyScanner` @StateObject, so onboarding broadcasts a
    /// notification that the Sovereignty tab's onReceive catches and
    /// turns into a `scanner.scan()` call.  Same pattern the menu-bar
    /// uses for tab routing.  Trust shares the result via its own
    /// scanner instance — the scan enumerates installed apps which
    /// both catalogs match against.
    private func runAudit() {
        NotificationCenter.default.post(
            name: .splynekRunSovereigntyScan, object: nil
        )
        didStartScan = true
    }

    private func complete() {
        vm.hasCompletedOnboarding = true
        dismiss()
    }
}
