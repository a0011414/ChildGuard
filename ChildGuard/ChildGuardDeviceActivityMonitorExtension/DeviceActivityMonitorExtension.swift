//
//  DeviceActivityMonitorExtension.swift
//  ChildGuardDeviceActivityMonitorExtension
//
//  しきい値到達時にシールドをかけ、のちに親へ通知する。
//

import DeviceActivity
import Foundation
import ManagedSettings
import FamilyControls
import UserNotifications

private enum ExtensionAppGroup {
    static let identifier = "group.com.yoshi.ChildGuard"
    static let familyActivitySelectionKey = "familyActivitySelection"
}

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        notifyForDebug("制限時間を超えました")
        applyShield()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // インターバル終了時はシールドを解除するかはポリシー次第。ここでは解除しない（翌日まで制限を維持する想定）
    }

    private func applyShield() {
        guard let defaults = UserDefaults(suiteName: ExtensionAppGroup.identifier),
              let data = defaults.data(forKey: ExtensionAppGroup.familyActivitySelectionKey),
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) else {
            notifyForDebug("シールドをかけられませんでした（選択の読み取りに失敗）")
            return
        }
        guard !selection.applicationTokens.isEmpty else {
            notifyForDebug("シールドをかけられませんでした（アプリが選ばれていません）")
            return
        }
        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens, except: Set())
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        // TODO: 親への通知（LINE 等）は MCP または Push で実装
    }

    /// デバッグ用：ローカル通知（Extension が呼ばれたか確認できる）
    private func notifyForDebug(_ body: String) {
        let content = UNMutableNotificationContent()
        content.title = "ChildGuard"
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
