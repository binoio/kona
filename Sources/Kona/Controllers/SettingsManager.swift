import Foundation
import ServiceManagement
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var showMenuBarItem: Bool {
        didSet {
            UserDefaults.standard.set(showMenuBarItem, forKey: "showMenuBarItem")
        }
    }
    @Published var showRemainingTimeInMenuBar: Bool {
        didSet {
            UserDefaults.standard.set(showRemainingTimeInMenuBar, forKey: "showRemainingTimeInMenuBar")
        }
    }
    @Published var openAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(openAtLogin, forKey: "openAtLogin")
            updateLoginItem()
        }
    }
    @Published var hasLaunched: Bool {
        didSet {
            UserDefaults.standard.set(hasLaunched, forKey: "hasLaunched")
        }
    }
    @Published var launchWakeStateId: UUID? {
        didSet {
            if let id = launchWakeStateId {
                UserDefaults.standard.set(id.uuidString, forKey: "launchWakeStateId")
            } else {
                UserDefaults.standard.removeObject(forKey: "launchWakeStateId")
            }
        }
    }
    
    private init() {
        showMenuBarItem = UserDefaults.standard.bool(forKey: "showMenuBarItem")
        if UserDefaults.standard.object(forKey: "showMenuBarItem") == nil {
            showMenuBarItem = true
        }
        showRemainingTimeInMenuBar = UserDefaults.standard.bool(forKey: "showRemainingTimeInMenuBar")
        openAtLogin = UserDefaults.standard.bool(forKey: "openAtLogin")
        hasLaunched = UserDefaults.standard.bool(forKey: "hasLaunched")
        if let idString = UserDefaults.standard.string(forKey: "launchWakeStateId") {
            launchWakeStateId = UUID(uuidString: idString)
        } else {
            launchWakeStateId = nil
        }
        updateLoginItem()
    }
    
    private func updateLoginItem() {
        if #available(macOS 13.0, *) {
            do {
                if openAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update login item: \(error)")
            }
        }
    }
}