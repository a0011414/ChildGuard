//
//  SharedConstants.swift
//  ChildGuard
//
//  本体アプリと Device Activity Extension で共有する定数。
//

import Foundation

/// App Group の識別子。Entitlements の com.apple.security.application-groups と一致させる。
enum AppGroup {
    static let identifier = "group.com.yoshi.ChildGuard"

    /// 共有 UserDefaults（本体・Extension の両方で同じ suiteName を指定する）
    static var shared: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }

    /// FamilyActivitySelection を保存する UserDefaults のキー
    static let familyActivitySelectionKey = "familyActivitySelection"

    /// 親への通知用 Cloud Functions のベース URL（末尾スラッシュなし）。未設定なら Extension は親通知を送らない。
    static let parentNotifyBaseURLKey = "parentNotifyBaseURL"

    /// デフォルトの FCM 用 Cloud Functions ベース URL（全員同じ。詳細で上書き可能）
    static let defaultFCMBaseURL = "https://us-central1-childguard-72f89.cloudfunctions.net"

    /// 家族コード（8桁）。親が発行し、子が入力 or QR で保存。Extension が notifyParent に渡す。
    static let familyIdKey = "familyId"

    /// この端末を「親用」として登録したか（端末ごと。UserDefaults.standard で保存）
    static let isParentDeviceKey = "ChildGuard.isParentDevice"
}
