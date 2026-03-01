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
}
