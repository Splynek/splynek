import SwiftUI
import AppKit

/// In-app viewer for the three load-bearing legal docs:
///   - EULA.md   (End-User Licence Agreement)
///   - PRIVACY.md (Privacy Policy)
///   - AUP.md    (Acceptable Use Policy)
///
/// Source of truth: `Resources/Legal/*.md` — bundled into the .app
/// at build time. The viewer loads the chosen doc, renders its
/// Markdown via `AttributedString(markdown:)`, and offers a *Reveal
/// in Finder* action + an *Email for questions* button.
struct LegalView: View {
    @ObservedObject var vm: SplynekViewModel
    @State private var selected: Doc = .eula

    enum Doc: String, CaseIterable, Identifiable {
        case eula     = "EULA.md"
        case privacy  = "PRIVACY.md"
        case aup      = "AUP.md"
        var id: String { rawValue }
        var title: String {
            switch self {
            case .eula:    return "End-User Licence Agreement"
            case .privacy: return "Privacy Policy"
            case .aup:     return "Acceptable Use Policy"
            }
        }
        var shortTitle: String {
            switch self {
            case .eula:    return "Licence"
            case .privacy: return "Privacy"
            case .aup:     return "Acceptable Use"
            }
        }
        var systemImage: String {
            switch self {
            case .eula:    return "doc.text.fill"
            case .privacy: return "lock.shield"
            case .aup:     return "hand.raised.fill"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PageHeader(
                    systemImage: "doc.text",
                    title: "Legal",
                    subtitle: "The documents that govern your use of Splynek. Read once, then scan when something changes."
                )
                picker
                viewer
                contactCard
            }
            .padding(20)
            .frame(maxWidth: 820)
        }
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Legal")
    }

    // MARK: Picker

    private var picker: some View {
        Picker("", selection: $selected) {
            ForEach(Doc.allCases) { doc in
                Label(doc.shortTitle, systemImage: doc.systemImage).tag(doc)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    // MARK: Document viewer

    private var viewer: some View {
        TitledCard(
            title: selected.title,
            systemImage: selected.systemImage,
            accessory: AnyView(
                HStack(spacing: 6) {
                    Button {
                        revealInFinder()
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .buttonStyle(.borderless)
                    .help("Reveal the source Markdown in Finder")
                }
            )
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if let md = loadDoc() {
                    renderedMarkdown(md)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Could not load \(selected.rawValue) from the app bundle. Please report this as a packaging issue.")
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    /// Render a Markdown document as an AttributedString, one paragraph
    /// per VStack row so headings and bullets render correctly. SwiftUI's
    /// `Text(AttributedString)` supports inline-Markdown out of the box,
    /// but not block-level features like headings — so we split on
    /// paragraph boundaries and apply our own font ramp.
    @ViewBuilder
    private func renderedMarkdown(_ md: String) -> some View {
        let blocks = parseBlocks(md)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .h1(let s):
                    Text(s).font(.system(.title, design: .rounded, weight: .bold))
                        .padding(.top, 6)
                case .h2(let s):
                    Text(s).font(.system(.title2, design: .rounded, weight: .semibold))
                        .padding(.top, 4)
                case .h3(let s):
                    Text(s).font(.system(.title3, design: .rounded, weight: .semibold))
                case .para(let s):
                    Text(attributed(s))
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                case .bullet(let s):
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundStyle(.secondary)
                        Text(attributed(s))
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, 4)
                case .numbered(let num, let s):
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(num).").monospacedDigit()
                            .foregroundStyle(.secondary)
                        Text(attributed(s))
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, 4)
                case .blank:
                    Spacer().frame(height: 2)
                }
            }
        }
    }

    enum Block {
        case h1(String), h2(String), h3(String)
        case para(String)
        case bullet(String)
        case numbered(Int, String)
        case blank
    }

    private func parseBlocks(_ md: String) -> [Block] {
        var out: [Block] = []
        let lines = md.components(separatedBy: "\n")
        var i = 0
        while i < lines.count {
            let raw = lines[i]
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                out.append(.blank); i += 1; continue
            }
            if trimmed.hasPrefix("### ") {
                out.append(.h3(String(trimmed.dropFirst(4)))); i += 1; continue
            }
            if trimmed.hasPrefix("## ") {
                out.append(.h2(String(trimmed.dropFirst(3)))); i += 1; continue
            }
            if trimmed.hasPrefix("# ") {
                out.append(.h1(String(trimmed.dropFirst(2)))); i += 1; continue
            }
            if trimmed.hasPrefix("- ") {
                out.append(.bullet(String(trimmed.dropFirst(2)))); i += 1; continue
            }
            // Numbered list item: "1. "..."99. ".
            if let dot = trimmed.firstIndex(of: "."),
               let n = Int(trimmed[..<dot]),
               trimmed.index(after: dot) < trimmed.endIndex,
               trimmed[trimmed.index(after: dot)] == " " {
                let s = String(trimmed[trimmed.index(dot, offsetBy: 2)...])
                out.append(.numbered(n, s)); i += 1; continue
            }
            // Merge continuation lines into a single paragraph — blank line
            // ends it.
            var para = trimmed
            var j = i + 1
            while j < lines.count {
                let nextRaw = lines[j]
                let next = nextRaw.trimmingCharacters(in: .whitespaces)
                if next.isEmpty { break }
                if next.hasPrefix("#") || next.hasPrefix("- ") { break }
                if let dot = next.firstIndex(of: "."),
                   let n = Int(next[..<dot]), n > 0,
                   next.index(after: dot) < next.endIndex,
                   next[next.index(after: dot)] == " " {
                    break
                }
                para += " " + next
                j += 1
            }
            out.append(.para(para))
            i = j
        }
        return out
    }

    private func attributed(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text,
                               options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
        ?? AttributedString(text)
    }

    // MARK: Contact card

    private var contactCard: some View {
        TitledCard(title: "Questions?", systemImage: "envelope") {
            VStack(alignment: .leading, spacing: 8) {
                Text("The three documents above form the complete agreement between you and Splynek's maintainers. If anything is unclear, or if you think a clause needs to change for your specific use, reach out:")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button {
                        if let u = URL(string: "mailto:info@splynek.app") {
                            NSWorkspace.shared.open(u)
                        }
                    } label: {
                        Label("Email info@splynek.app", systemImage: "envelope.fill")
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                Text("These documents are templates provided in good faith. Before deploying Splynek in a context where legal precision matters (business use, enterprise distribution, unusual jurisdictions), have your own counsel review them.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Loader

    private func loadDoc() -> String? {
        let candidates = [
            Bundle.main.resourceURL?
                .appendingPathComponent("Legal/\(selected.rawValue)"),
            Bundle.main.url(forResource: selected.rawValue.replacingOccurrences(of: ".md", with: ""),
                            withExtension: "md",
                            subdirectory: "Legal")
        ]
        for opt in candidates {
            if let url = opt, let s = try? String(contentsOf: url, encoding: .utf8) {
                return s
            }
        }
        return nil
    }

    private func revealInFinder() {
        guard let url = Bundle.main.resourceURL?
                .appendingPathComponent("Legal/\(selected.rawValue)") else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
