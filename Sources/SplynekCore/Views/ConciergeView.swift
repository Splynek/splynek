import SwiftUI

/// AI Concierge — a chat-first entry point into Splynek.
///
/// Users type whatever they want:
///   "download the latest Ubuntu desktop ISO"
///   "add the new kernel to the queue"
///   "cancel everything"
///   "what did I download from github last week?"
///
/// The concierge classifies the intent via the local LLM, dispatches
/// the right action (start download / queue / search history / cancel
/// / pause), and responds in the chat. One conversation replaces
/// hunting across Download / Queue / History tabs.
struct ConciergeView: View {
    @ObservedObject var vm: SplynekViewModel
    @State private var draft: String = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if !vm.aiChat.isEmpty {
                PageHeader(
                    systemImage: "sparkles",
                    title: "Assistant",
                    subtitle: "Say it in plain English — downloads, queue, history, and app actions. Powered by your local LLM, offline."
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            transcript
            Divider()
            inputBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Assistant")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    vm.conciergeReset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .help("Clear the conversation")
                .disabled(vm.aiChat.isEmpty)
            }
        }
        .onAppear { inputFocused = true }
    }

    // MARK: Transcript

    @ViewBuilder
    private var transcript: some View {
        if vm.aiChat.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(vm.aiChat) { msg in
                            bubble(msg).id(msg.id)
                        }
                        if vm.aiConciergeThinking {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text("Concierge thinking…")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 16)
                }
                .onChange(of: vm.aiChat.count) { _ in
                    if let last = vm.aiChat.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .accentColor],
                                   startPoint: .top, endPoint: .bottom)
                )
            Text("Tell Splynek what you want")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            Text("Downloads, queue, history lookups, and app actions — all through one conversation. Runs on your local LLM, offline.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)

            if vm.aiAvailable, let model = vm.aiModel {
                VStack(spacing: 8) {
                    suggestionChip("Download the latest Ubuntu desktop ISO")
                    suggestionChip("Add kernel.org’s latest stable to the queue")
                    suggestionChip("What did I download from github last week?")
                    suggestionChip("Cancel everything")
                }
                Text("Using \(model)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                VStack(spacing: 10) {
                    Label("Install Ollama to enable the Concierge", systemImage: "sparkles")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button {
                        if let u = URL(string: "https://ollama.com/download") {
                            NSWorkspace.shared.open(u)
                        }
                    } label: {
                        Label("Install Ollama", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    private func suggestionChip(_ text: String) -> some View {
        Button {
            draft = text
            vm.conciergeSend(text)
            draft = ""
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(.purple)
                Text(text).font(.callout)
                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.purple.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.purple.opacity(0.25), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 440)
    }

    // MARK: Bubble

    @ViewBuilder
    private func bubble(_ msg: SplynekViewModel.ConciergeMessage) -> some View {
        let isUser = msg.role == .user
        let isSystem = msg.role == .system
        HStack(alignment: .top, spacing: 10) {
            if isUser { Spacer(minLength: 40) }
            if !isUser {
                Image(systemName: isSystem ? "info.circle.fill" : "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSystem ? .orange : .purple)
                    .frame(width: 22, alignment: .center)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(msg.text)
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(bubbleFill(isUser: isUser, isSystem: isSystem))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(bubbleBorder(isUser: isUser, isSystem: isSystem),
                                          lineWidth: 0.5)
                    )
                    .fixedSize(horizontal: false, vertical: true)
                if let action = msg.action {
                    StatusPill(text: action, style: .info)
                        .padding(.leading, 4)
                }
            }
            if !isUser { Spacer(minLength: 40) }
        }
        .padding(.horizontal, 16)
    }

    private func bubbleFill(isUser: Bool, isSystem: Bool) -> Color {
        if isSystem { return Color.orange.opacity(0.10) }
        return isUser
            ? Color.accentColor.opacity(0.18)
            : Color.primary.opacity(0.05)
    }
    private func bubbleBorder(isUser: Bool, isSystem: Bool) -> Color {
        if isSystem { return Color.orange.opacity(0.35) }
        return isUser
            ? Color.accentColor.opacity(0.30)
            : Color.primary.opacity(0.10)
    }

    // MARK: Input bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles").foregroundStyle(.purple)
            TextField("Ask anything — “download the latest Ubuntu ISO”", text: $draft)
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .onSubmit(submit)
                .disabled(vm.aiConciergeThinking)
            if vm.aiConciergeThinking {
                ProgressView().controlSize(.small)
            } else {
                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(draftValid ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .disabled(!draftValid)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var draftValid: Bool {
        !draft.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submit() {
        guard draftValid else { return }
        let text = draft
        draft = ""
        vm.conciergeSend(text)
    }
}
