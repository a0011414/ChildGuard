//
//  ParentNotificationService.swift
//  ChildGuard
//
//  親端末の FCM トークンを取得し、Cloud Functions に登録する。
//  親への通知用 URL は App Group に保存し、Extension から参照する。
//

import Foundation

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

/// 親登録の失敗理由（Result の Failure は Error 準拠が必要なため）
struct ParentNotificationError: Error {
    let message: String
}

enum ParentNotificationService {

    /// FCM トークンを取得する（Firebase 未リンク時は nil）。取得できない場合は少し待って1回だけ再試行する。
    static func getFCMToken() async -> String? {
        #if canImport(FirebaseMessaging)
        func fetch() async -> String? {
            await withCheckedContinuation { continuation in
                Messaging.messaging().token { token, _ in
                    continuation.resume(returning: token)
                }
            }
        }
        if let token = await fetch() { return token }
        try? await Task.sleep(nanoseconds: 2_500_000_000) // 2.5秒待ってから再試行（APNs→FCM の反映待ち）
        return await fetch()
        #else
        return nil
        #endif
    }

    /// 親としてこの端末を登録する。baseURL に registerParentToken を POST し、成功時に baseURL と familyId を App Group に保存する。
    /// - Parameters:
    ///   - baseURL: Cloud Functions のベース URL
    ///   - existingFamilyId: 既に持っている家族コード（再登録・トークン更新時）。nil なら新規発行。
    /// - Returns: 成功時は発行または更新した familyId（8桁）
    static func registerAsParent(baseURL: String, existingFamilyId: String? = nil) async -> Result<String, ParentNotificationError> {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        else {
            return .failure(ParentNotificationError(message: "URL を入力してください"))
        }
        let registerURL = url.appendingPathComponent("registerParentToken")
        // バンドルに GoogleService-Info.plist が含まれているか先に確認
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") == nil {
            return .failure(ParentNotificationError(message: "GoogleService-Info.plist がアプリに含まれていません。Xcode で ChildGuard ターゲットの「Build Phases」→「Copy Bundle Resources」に GoogleService-Info.plist を追加してください。"))
        }
        guard let token = await getFCMToken() else {
            let isSimulator = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
            if isSimulator {
                return .failure(ParentNotificationError(message: "シミュレータでは FCM トークンを取得できません。親として登録するには、実機の iPhone でアプリを起動し、「親としてこの端末を登録」をタップしてください。"))
            }
            return .failure(ParentNotificationError(message: "FCM トークンを取得できません。実機で「設定」→「ChildGuard」→「通知」をオンにし、アプリを再起動してから再度お試しください。Push Notifications の Capability も確認してください。"))
        }
        var body: [String: Any] = ["token": token]
        if let id = existingFamilyId, !id.isEmpty { body["familyId"] = id }
        var request = URLRequest(url: registerURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(ParentNotificationError(message: "応答が不正です"))
            }
            guard (200 ..< 300).contains(http.statusCode) else {
                return .failure(ParentNotificationError(message: "登録に失敗しました（HTTP \(http.statusCode)）"))
            }
            let saveURL = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
            AppGroup.shared?.set(saveURL, forKey: AppGroup.parentNotifyBaseURLKey)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let familyId = json["familyId"] as? String {
                AppGroup.shared?.set(familyId, forKey: AppGroup.familyIdKey)
                return .success(familyId)
            }
            return .failure(ParentNotificationError(message: "サーバーから家族コードを取得できませんでした"))
        } catch {
            return .failure(ParentNotificationError(message: "通信エラー: \(error.localizedDescription)"))
        }
    }
}
