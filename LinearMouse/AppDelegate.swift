//
//  AppDelegate.swift
//  LinearMouse
//
//  Created by lujjjh on 2021/6/10.
//

import Combine
import SwiftUI
import os.log

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private static let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "AppDelegate")

    private let autoUpdateManager = AutoUpdateManager.shared
    private let statusItem = StatusItem.shared
    private var defaultsSubscription: AnyCancellable!
    private var eventTap: EventTap?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        withAccessibilityPermission {
            // register the start entry if the user grants the permission
            AutoStartManager.enable()

            // scrolling functionalities
            let eventTap = EventTap()
            eventTap.enable()
            self.eventTap = eventTap

            // subscribe to the user settings
            let defaults = AppDefaults.shared
            self.defaultsSubscription = defaults.objectWillChange.sink { _ in
                DispatchQueue.main.async {
                    self.update(defaults)
                }
            }
            self.update(defaults)

            NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil,
                                                              queue: nil, using: { _ in
                DispatchQueue.main.async {
                    os_log("Session inactive", log: Self.log, type: .debug)
                    if let eventTap = self.eventTap {
                        eventTap.disable()
                    }
                    DeviceManager.shared.pause()
                }
            })

            NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil,
                                                              queue: nil, using: { _ in
                DispatchQueue.main.async {
                    os_log("Session active", log: Self.log, type: .debug)
                    if let eventTap = self.eventTap {
                        eventTap.enable()
                    }
                    DeviceManager.shared.resume()
                }
            })
        }
    }

    func withAccessibilityPermission(shouldAskForPermission: Bool = true, completion: @escaping () -> Void) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): shouldAskForPermission] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                os_log("Re-checking accessibility permission", log: Self.log, type: .debug)
                self.withAccessibilityPermission(shouldAskForPermission: false, completion: completion)
            }
            return
        }
        completion()
    }

    func update(_ defaults: AppDefaults) {
        DeviceManager.shared.updatePointerSpeed(acceleration: defaults.cursorAcceleration, sensitivity: defaults.cursorSensitivity, disableAcceleration: defaults.linearMovementOn)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag {
            return true
        }
        statusItem.openPreferencesAction()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        DeviceManager.shared.pause()
    }
}
