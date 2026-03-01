//
//  DeviceActivityMonitoring.swift
//  ChildGuard
//
//  本体アプリから Device Activity の監視を開始する。
//

import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

extension DeviceActivityName {
    static let dailyLimit = DeviceActivityName("dailyLimit")
}

extension DeviceActivityEvent.Name {
    static let limitReached = DeviceActivityEvent.Name("limitReached")
}

enum DeviceActivityMonitoring {

    /// 保存された選択と1日上限（分）で監視を開始する。結果メッセージを返す（nil = 成功）。
    static func startIfPossible(dailyLimitMinutes: Int) -> String? {
        guard dailyLimitMinutes > 0 else {
            return "1日の上限（分）を設定してください。"
        }
        guard let defaults = AppGroup.shared else {
            return "App Group が利用できません。"
        }
        guard let data = defaults.data(forKey: AppGroup.familyActivitySelectionKey),
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return "先に「制限するアプリ・Web」を選んで「この選択を保存」をタップしてください。"
        }
        guard !selection.applicationTokens.isEmpty else {
            return "「アプリ」タブで個別のアプリを1つ以上選んでから「この選択を保存」をタップしてください。カテゴリだけでは監視を開始できません。"
        }

        let threshold = DateComponents(minute: dailyLimitMinutes)
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )
        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            threshold: threshold
        )

        let center = DeviceActivityCenter()
        do {
            try center.startMonitoring(.dailyLimit, during: schedule, events: [.limitReached: event])
            // 本体で一度 Store を触っておく（Extension 側のシールド適用が効きやすくなる場合がある）
            let store = ManagedSettingsStore()
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            store.shield.webDomains = nil
            return nil // 成功
        } catch {
            return "監視の開始に失敗しました: \(error.localizedDescription)"
        }
    }

    static func stop() {
        DeviceActivityCenter().stopMonitoring([.dailyLimit])
    }
}
