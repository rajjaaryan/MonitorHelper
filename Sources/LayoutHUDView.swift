import AppKit
import Combine
import SwiftUI

/// Backing state for the HUD, mutated by `HUDController`.
final class HUDModel: ObservableObject {
    @Published var layout: Layout = .left
    @Published var isVisible: Bool = false
}

/// Real macOS "frosted glass" via NSVisualEffectView. `.hudWindow` +
/// behind-window blending strongly blurs/smudges whatever is behind the panel.
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
        view.state = .active
    }
}

/// The frosted-glass confirmation card shown after a switch.
struct LayoutHUDView: View {
    var layout: Layout

    private let corner: CGFloat = 28

    var body: some View {
        VStack(spacing: 18) {
            LayoutDiagram(layout: layout, scale: 1.55)
            VStack(spacing: 4) {
                Text(layout.label)
                    .font(.title.weight(.semibold))
                Text("Displays rearranged")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 34)
        .frame(width: 360)
        .background(
            VisualEffectView(material: .hudWindow, blending: .behindWindow)
                .overlay(Color.primary.opacity(0.04))          // extra frosted tint
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 36, y: 12)
    }
}

/// Root of the HUD hosting view — owns the enter/exit animation.
struct HUDRootView: View {
    @ObservedObject var model: HUDModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        LayoutHUDView(layout: model.layout)
            .opacity(model.isVisible ? 1 : 0)
            .offset(y: model.isVisible ? 0 : (reduceMotion ? 0 : 16))
            .scaleEffect(model.isVisible ? 1 : (reduceMotion ? 1 : 0.95))
            .animation(reduceMotion ? .easeInOut(duration: 0.22)
                                    : .spring(response: 0.42, dampingFraction: 0.82),
                       value: model.isVisible)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(36) // breathing room so the card's shadow isn't clipped
    }
}
