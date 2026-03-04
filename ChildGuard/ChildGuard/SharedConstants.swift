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

    /// この端末を「親用」として登録したか（端末ごと。UserDefaults.standard で保存。親役割選択時に true にする）
    static let isParentDeviceKey = "ChildGuard.isParentDevice"

    /// 初回選択した役割（"parent" / "child"）。未設定は nil。UserDefaults.standard で保存。設定後は切り替え不可。
    static let roleKey = "ChildGuard.role"
}
