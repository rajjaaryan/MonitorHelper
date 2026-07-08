import Combine
import Foundation
import ServiceManagement

/// Where the confirmation HUD appears on screen.
enum HUDPosition: String, CaseIterable, Identifiable {
    case bottomCenter, topCenter, center, bottomLeft, bottomRight, topLeft, topRight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bottomCenter: return "Bottom Center"
        case .topCenter:    return "Top Center"
        case .center:       return "Center"
        case .bottomLeft:   return "Bottom Left"
        case .bottomRight:  return "Bottom Right"
        case .topLeft:      return "Top Left"
        case .topRight:     return "Top Right"
        }
    }
}

/// UserDefaults-backed, observable app preferences.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard
    private let hudKey = "hudPosition"

    @Published var hudPosition: HUDPosition {
        didSet { defaults.set(hudPosition.rawValue, forKey: hudKey) }
    }

    init() {
        let raw = defaults.string(forKey: hudKey) ?? HUDPosition.bottomCenter.rawValue
        hudPosition = HUDPosition(rawValue: raw) ?? .bottomCenter
    }
}

/// Thin wrapper over `SMAppService.mainApp` for the "Start at Login" toggle.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("MonitorHelper: LoginItem toggle failed: \(error.localizedDescription)")
        }
    }
}
