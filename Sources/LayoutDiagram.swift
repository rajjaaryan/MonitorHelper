import SwiftUI

/// A small vector diagram of the monitor + laptop arrangement.
///
/// The monitor is fixed at the top-left; the laptop tile animates from its old
/// position to the new one whenever `layout` changes — the "springs into place"
/// effect. Reused in the HUD and the menu card. `scale` sizes the whole glyph.
struct LayoutDiagram: View {
    var layout: Layout
    var scale: CGFloat = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var monitor: CGSize { CGSize(width: 84 * scale, height: 52 * scale) }
    private var laptop: CGSize  { CGSize(width: 46 * scale, height: 30 * scale) }
    private var gap: CGFloat    { 8 * scale }

    // Canvas is sized to hold either arrangement; the whole group is centered
    // within it in each state, so both layouts look balanced while the monitor
    // and laptop animate into their new positions.
    private var canvas: CGSize {
        CGSize(width: laptop.width + gap + monitor.width,
               height: monitor.height + gap + laptop.height)
    }

    private var monitorOffset: CGSize {
        switch layout {
        case .left:  return CGSize(width: laptop.width + gap,
                                   height: (canvas.height - monitor.height) / 2)
        case .below: return CGSize(width: (canvas.width - monitor.width) / 2,
                                   height: 0)
        }
    }

    private var laptopOffset: CGSize {
        switch layout {
        case .left:  return CGSize(width: 0,
                                   height: (canvas.height - laptop.height) / 2)
        case .below: return CGSize(width: (canvas.width - laptop.width) / 2,
                                   height: monitor.height + gap)
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4 * scale, style: .continuous)
                .fill(Color.secondary.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 4 * scale, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.45), lineWidth: 1)
                )
                .frame(width: monitor.width, height: monitor.height)
                .offset(monitorOffset)

            RoundedRectangle(cornerRadius: 3 * scale, style: .continuous)
                .fill(Color.accentColor)
                .frame(width: laptop.width, height: laptop.height)
                .shadow(color: Color.accentColor.opacity(0.35), radius: 4 * scale, y: 1)
                .offset(laptopOffset)
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        .animation(reduceMotion ? .easeInOut(duration: 0.2)
                                : .spring(response: 0.42, dampingFraction: 0.72),
                   value: layout)
    }
}
