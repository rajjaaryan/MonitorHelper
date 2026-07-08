import SwiftUI

/// Entry point. With a command-line flag it performs a one-shot action and
/// exits (handy for scripting / testing); otherwise it launches the menu-bar app.
@main
enum EntryPoint {
    static func main() {
        let args = CommandLine.arguments.dropFirst()
        if let cmd = args.first, cmd.hasPrefix("--") {
            switch cmd {
            case "--toggle":
                print(DisplayManager.shared.toggle()?.rawValue ?? "none")
            case "--left":
                print(DisplayManager.shared.apply(.left) ? "left" : "none")
            case "--below":
                print(DisplayManager.shared.apply(.below) ? "below" : "none")
            case "--status":
                print(DisplayManager.shared.currentLayout?.rawValue ?? "none")
            default:
                FileHandle.standardError.write(Data("Usage: MonitorHelper [--toggle|--left|--below|--status]\n".utf8))
            }
            return
        }
        MonitorHelperApp.main()
    }
}

struct MonitorHelperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)
    }
}

/// State-reflecting menu-bar icon.
struct MenuBarLabel: View {
    @ObservedObject private var displays = DisplayManager.shared

    private var symbol: String {
        switch displays.currentLayout {
        case .left:  return "rectangle.lefthalf.inset.filled"
        case .below: return "rectangle.bottomhalf.inset.filled"
        case .none:  return "display"
        }
    }

    var body: some View {
        Image(systemName: symbol)
    }
}

/// The window-style panel shown when the menu-bar icon is clicked.
struct MenuContentView: View {
    @ObservedObject private var displays = DisplayManager.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var launchAtLogin = LoginItem.isEnabled

    private var statusText: String {
        guard displays.hasExternalDisplay else { return "No external monitor" }
        switch displays.currentLayout {
        case .left:  return "Laptop is to the left"
        case .below: return "Laptop is below"
        case .none:  return "—"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 12) {
                LayoutDiagram(layout: displays.currentLayout ?? .left, scale: 0.5)
                    .opacity(displays.hasExternalDisplay ? 1 : 0.35)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MonitorHelper").font(.headline)
                    Text(statusText).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            // Manual layout selection
            VStack(spacing: 8) {
                LayoutButton(target: .left, current: displays.currentLayout) {
                    AppController.shared.apply(.left)
                }
                LayoutButton(target: .below, current: displays.currentLayout) {
                    AppController.shared.apply(.below)
                }
            }
            .disabled(!displays.hasExternalDisplay)

            Label("Toggle shortcut:  ⌃⌥⌘D", systemImage: "keyboard")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Toggle("Start at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    LoginItem.setEnabled(newValue)
                }

            Picker("Overlay position", selection: $settings.hudPosition) {
                ForEach(HUDPosition.allCases) { pos in
                    Text(pos.title).tag(pos)
                }
            }

            Divider()

            Button("Quit MonitorHelper") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(16)
        .frame(width: 280)
        .onAppear {
            displays.refresh()
            launchAtLogin = LoginItem.isEnabled
        }
    }
}

/// A tappable row with a mini diagram of the target layout + a "current" check.
struct LayoutButton: View {
    var target: Layout
    var current: Layout?
    var action: () -> Void

    private var isCurrent: Bool { current == target }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                LayoutDiagram(layout: target, scale: 0.4)
                Text(target.label)
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(isCurrent ? 0.18 : 0.08))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
