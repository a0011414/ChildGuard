//
//  DeviceActivityMonitorExtension.swift
//  ChildGuardDeviceActivityMonitorExtension
//
//  しきい値到達時にシールドをかけ、のちに親へ通知する。
//

import DeviceActivity
import ManagedSettings
import FamilyControls

private enum ExtensionAppGroup {
    static let identifier = "group.com.yoshi.ChildGuard"
    static let familyActivitySelectionKey = "familyActivitySelection"
}

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        applyShield()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // インターバル終了時はシールドを解除するかはポリシー次第。ここでは解除しない（翌日まで制限を維持する想定）
    }

    private func applyShield() {
        guard let defaults = UserDefaults(suiteName: ExtensionAppGroup.identifier),
              let data = defaults.data(forKey: ExtensionAppGroup.familyActivitySelectionKey),
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) else { return }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens, except: Set())
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        // TODO: 親への通知（LINE 等）は MCP または Push で実装
    }
}
