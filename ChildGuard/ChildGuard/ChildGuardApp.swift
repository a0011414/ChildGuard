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
    @StateObject private var ruleStore = RuleStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ruleStore)
                .onOpenURL { url in
                    handleShareURL(url)
                }
        }
    }

    private func handleShareURL(_ url: URL) {
        let store = ruleStore
        CKContainer.default().fetchShareMetadata(with: url) { metadata, error in
            guard let metadata = metadata else { return }
            DispatchQueue.main.async {
                store.acceptShare(metadata: metadata) { _ in }
            }
        }
    }
}
