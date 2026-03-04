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
    static let parentNotifyBaseURLKey = "parentNotifyBaseURL"
    static let familyIdKey = "familyId"
    static let defaultFCMBaseURL = "https://us-central1-childguard-72f89.cloudfunctions.net"
}

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        notifyForDebug("制限時間を超えました")
        applyShield()
        notifyParentIfConfigured()
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
    }

    /// 家族コードと URL が登録されていれば、Cloud Functions の notifyParent に familyId を渡して呼ぶ
    private func notifyParentIfConfigured() {
        guard let defaults = UserDefaults(suiteName: ExtensionAppGroup.identifier),
              let familyId = defaults.string(forKey: ExtensionAppGroup.familyIdKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
              familyId.count == 8,
              familyId.allSatisfy(\.isNumber)
        else { return }
        let baseURL = defaults.string(forKey: ExtensionAppGroup.parentNotifyBaseURLKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ExtensionAppGroup.defaultFCMBaseURL
        guard let url = URL(string: baseURL.hasSuffix("/") ? baseURL + "notifyParent" : baseURL + "/notifyParent")
        else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body = try? JSONSerialization.data(withJSONObject: ["familyId": familyId]) {
            request.httpBody = body
        }
        let task = URLSession.shared.dataTask(with: request) { _, _, _ in }
        task.resume()
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
