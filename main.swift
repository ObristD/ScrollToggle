import Cocoa
import ServiceManagement

// MARK: - System setting access (same private call System Settings uses)

enum ScrollDirection {
    private static let handle = dlopen(
        "/System/Library/PrivateFrameworks/PreferencePanesSupport.framework/PreferencePanesSupport", RTLD_NOW)

    private typealias GetFn = @convention(c) () -> Bool
    private typealias SetFn = @convention(c) (Bool) -> Void

    private static let getFn: GetFn? = {
        guard let h = handle, let p = dlsym(h, "swipeScrollDirection") else { return nil }
        return unsafeBitCast(p, to: GetFn.self)
    }()
    private static let setFn: SetFn? = {
        guard let h = handle, let p = dlsym(h, "setSwipeScrollDirection") else { return nil }
        return unsafeBitCast(p, to: SetFn.self)
    }()

    static var available: Bool { getFn != nil && setFn != nil }

    /// true = "Natural" (content follows finger), false = "Standard" (classic mouse wheel)
    static var isNatural: Bool {
        get {
            if let f = getFn { return f() }
            return UserDefaults.standard.object(forKey: "com.apple.swipescrolldirection") as? Bool ?? true
        }
        set {
            if let f = setFn {
                f(newValue)
            } else {
                // Fallback: write the default and tell the system about it.
                CFPreferencesSetValue("com.apple.swipescrolldirection" as CFString,
                                      newValue as CFBoolean,
                                      kCFPreferencesAnyApplication,
                                      kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
                CFPreferencesSynchronize(kCFPreferencesAnyApplication,
                                         kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
                DistributedNotificationCenter.default().postNotificationName(
                    NSNotification.Name("SwipeScrollDirectionDidChangeNotification"),
                    object: nil, userInfo: nil, deliverImmediately: true)
            }
        }
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let toggleItem = NSMenuItem(title: "", action: #selector(toggle), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        toggleItem.target = self
        loginItem.target = self
        menu.delegate = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // Keep the icon in sync when the setting is changed in System Settings.
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(refresh),
            name: NSNotification.Name("SwipeScrollDirectionDidChangeNotification"), object: nil)
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.refresh() }

        refresh()
    }

    @objc private func statusItemClicked() {
        let isRightClick = NSApp.currentEvent?.type == .rightMouseUp
            || NSApp.currentEvent?.modifierFlags.contains(.control) == true
        if isRightClick {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil   // detach again so left-click keeps toggling
        } else {
            toggle()
        }
    }

    @objc private func toggle() {
        ScrollDirection.isNatural.toggle()
        refresh()
    }

    @objc private func refresh() {
        let natural = ScrollDirection.isNatural
        let symbol = natural ? "hand.draw.fill" : "computermouse.fill"
        let label = natural ? "Natural" : "Standard"
        if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: "Scroll direction: \(label)") {
            img.isTemplate = true
            statusItem.button?.image = img
        }
        statusItem.button?.toolTip = "Scroll direction: \(label)\nClick to switch · Right-click for menu"
        toggleItem.title = natural ? "Natural scrolling (content follows finger)"
                                   : "Standard scrolling (classic wheel)"
        toggleItem.state = natural ? .on : .off
    }

    // MARK: Launch at login

    func menuNeedsUpdate(_ menu: NSMenu) {
        refresh()
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not change login item"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}

// Command-line helpers: `ScrollToggle --login-on` / `--login-off` register or
// unregister the app as a login item and exit (used by the installer).
if CommandLine.arguments.contains("--login-on") || CommandLine.arguments.contains("--login-off") {
    do {
        if CommandLine.arguments.contains("--login-on") {
            try SMAppService.mainApp.register()
            print("Launch at Login: enabled")
        } else {
            try SMAppService.mainApp.unregister()
            print("Launch at Login: disabled")
        }
        exit(0)
    } catch {
        FileHandle.standardError.write("Failed: \(error.localizedDescription)\n".data(using: .utf8)!)
        exit(1)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
