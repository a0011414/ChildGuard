//
//  DeviceActivityMonitoring.swift
//  ChildGuard
//
//  本体アプリから Device Activity の監視を開始する。
//

import DeviceActivity
import FamilyControls

extension DeviceActivityName {
    static let dailyLimit = DeviceActivityName("dailyLimit")
}

extension DeviceActivityEvent.Name {
    static let limitReached = DeviceActivityEvent.Name("limitReached")
}

enum DeviceActivityMonitoring {

    /// 保存された選択と1日上限（分）で監視を開始する。選択が空や上限が0の場合は何もしない。
    static func startIfPossible(dailyLimitMinutes: Int) {
        guard dailyLimitMinutes > 0,
              let defaults = AppGroup.shared,
              let data = defaults.data(forKey: AppGroup.familyActivitySelectionKey),
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data),
              !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty else { return }

        let threshold = DateComponents(minute: dailyLimitMinutes)
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )

        // アプリトークンのみでイベントを定義（しきい値は「そのアプリ群の合計使用時間」）
        guard !selection.applicationTokens.isEmpty else { return }
        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            threshold: threshold
        )

        let center = DeviceActivityCenter()
        do {
            try center.startMonitoring(.dailyLimit, during: schedule, events: [.limitReached: event])
        } catch {
            // 監視開始に失敗（既に監視中、または権限不足など）
            print("DeviceActivity startMonitoring failed: \(error)")
        }
    }

    static func stop() {
        DeviceActivityCenter().stopMonitoring([.dailyLimit])
    }
}
