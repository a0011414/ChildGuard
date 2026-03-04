//
//  ChildGuardApp.swift
//  ChildGuard
//
//  親子で決めたルールに従い、制限・通知するアプリ。
//

import SwiftUI
import CloudKit

@main
struct ChildGuardApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var ruleStore = RuleStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ruleStore)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "childguard" else {
            handleCloudKitShareURL(url)
            return
        }
        // childguard://rule?minutes=60 の形式（QR で渡したルール）
        if url.host == "rule",
           let comp = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let minutes = comp.queryItems?.first(where: { $0.name == "minutes" })?.value.flatMap(Int.init),
           minutes > 0 {
            DispatchQueue.main.async {
                ruleStore.applyRuleFromQR(dailyLimitMinutes: minutes)
            }
            return
        }
        handleCloudKitShareURL(url)
    }

    private func handleCloudKitShareURL(_ url: URL) {
        let store = ruleStore
        let container = CKContainer(identifier: "iCloud.com.yoshi.ChildGuard")
        container.fetchShareMetadata(with: url) { metadata, error in
            guard let metadata = metadata else { return }
            DispatchQueue.main.async {
                store.acceptShare(metadata: metadata) { _ in }
            }
        }
    }
}
