import SwiftUI
import AppKit

/// 2026-05-06 — UI/UX pass: SwiftUI on macOS has weak default hover
/// affordances.  `.buttonStyle(.borderless)` (which Splynek uses for
/// most icon-only action buttons) shows ZERO visual hover feedback,
/// and SwiftUI never changes the cursor over interactive elements
/// the way a native AppKit button does.  Result: users can't tell
/// what's clickable until they actually click.
///
/// This file ships two reusable primitives that fix that across the
/// app:
///
/// - `.splynekHover()` — apply to any tappable area (rows, cards,
///   custom HStacks with `.onTapGesture`).  Adds a subtle background
///   tint on hover + sets the cursor to `pointingHand` while the
///   pointer is over it.
///
/// - `.splynekButtonStyle()` / `SplynekButtonStyle` — drop-in
///   replacement for `.borderless` that adds hover tint + cursor.
///   Same chrome as the standard borderless button (just text/icon,
///   no chip), but actually responds to mouse-over.
///
/// Both honor `@Environment(\.isEnabled)` — disabled buttons get no
/// hover effect and no cursor change (the system shows the standard
/// not-allowed cursor on disabled controls automatically).

extension View {

    /// Add hover affordances: subtle background tint + pointing-hand
    /// cursor.  Apply to anything the user clicks that isn't a
    /// stock SwiftUI Button (those should use `.splynekButtonStyle()`).
    ///
    /// `cornerRadius` defaults to 6 (matches our standard chip /
    /// row corner radius); pass a different value for tighter or
    /// looser shapes.  `tint` overrides the default subtle gray
    /// tint — pass `Color.accentColor.opacity(0.12)` for an "accent
    /// invitation" hover state on important CTAs.
    public func splynekHover(
        cornerRadius: CGFloat = 6,
        tint: Color = .primary.opacity(0.06),
        cursor: NSCursor = .pointingHand
    ) -> some View {
        modifier(SplynekHoverModifier(
            cornerRadius: cornerRadius,
            tint: tint,
            cursor: cursor
        ))
    }

    /// Cursor-only variant: change the pointer shape without
    /// adding a background tint.  Useful for inline links inside
    /// paragraph text where a tint would feel heavy-handed.
    public func splynekHoverCursor(_ cursor: NSCursor = .pointingHand) -> some View {
        onHover { hovering in
            if hovering {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

/// Visual hover effect: subtle tint behind the content + pointing-
/// hand cursor while the pointer is over.  Animated 120ms ease-out;
/// doesn't transition the cursor (system handles that instantly).
struct SplynekHoverModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color
    let cursor: NSCursor
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isHovering && isEnabled ? tint : Color.clear)
                    .animation(.easeOut(duration: 0.12), value: isHovering)
            )
            .onHover { hovering in
                guard isEnabled else { return }
                isHovering = hovering
                // NSCursor.push/pop is the macOS 13+ way.  The system
                // unbalances cleanly when the view detaches — no leak
                // even if the pointer leaves while we're being torn
                // down (AppKit re-resolves the cursor on the next
                // event loop tick).
                if hovering {
                    cursor.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

/// Custom Button style that includes hover affordance.  Drop-in
/// replacement for `.buttonStyle(.borderless)` — same visual chrome,
/// plus background tint on hover + pointing-hand cursor.
///
/// Use for icon-only / chip-style action buttons throughout the app.
/// For primary CTAs keep `.buttonStyle(.borderedProminent)` (which
/// already has its own hover state from AppKit).
public struct SplynekHoverButtonStyle: ButtonStyle {
    let cornerRadius: CGFloat
    let tint: Color

    public init(
        cornerRadius: CGFloat = 6,
        tint: Color = .primary.opacity(0.08)
    ) {
        self.cornerRadius = cornerRadius
        self.tint = tint
    }

    public func makeBody(configuration: Configuration) -> some View {
        SplynekHoverButton(
            configuration: configuration,
            cornerRadius: cornerRadius,
            tint: tint
        )
    }
}

private struct SplynekHoverButton: View {
    let configuration: ButtonStyle.Configuration
    let cornerRadius: CGFloat
    let tint: Color
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundFill)
                    .animation(.easeOut(duration: 0.12), value: isHovering)
                    .animation(.easeOut(duration: 0.05), value: configuration.isPressed)
            )
            .opacity(isEnabled ? 1.0 : 0.5)
            .onHover { hovering in
                guard isEnabled else { return }
                isHovering = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }

    private var backgroundFill: Color {
        guard isEnabled else { return .clear }
        if configuration.isPressed { return tint.opacity(1.6) }  // pressed: stronger
        if isHovering { return tint }
        return .clear
    }
}

extension ButtonStyle where Self == SplynekHoverButtonStyle {
    /// Sugar so call sites read `.buttonStyle(.splynekHover)`.
    public static var splynekHover: SplynekHoverButtonStyle {
        SplynekHoverButtonStyle()
    }
}
