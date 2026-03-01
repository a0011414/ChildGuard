//
//  ContentView.swift
//  ChildGuard
//
//  親モード / 子モード の切り替え（1本のアプリで対応）
//

import SwiftUI
import FamilyControls
import ManagedSettings

enum AppMode: String, CaseIterable {
    case parent = "親"
    case child = "子"
}

struct ContentView: View {
    @EnvironmentObject var ruleStore: RuleStore
    @State private var mode: AppMode = .parent

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Picker("モード", selection: $mode) {
                    ForEach(AppMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Group {
                    switch mode {
                    case .parent:
                        ParentModeView(store: ruleStore)
                    case .child:
                        ChildModeView(store: ruleStore)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Spacer()
            }
            .navigationTitle("ChildGuard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .padding()
        }
    }
}

struct ParentModeView: View {
    @ObservedObject var store: RuleStore
    @State private var inputMinutes: String = ""
    @State private var shareItem: IdentifiableURL?
    @State private var isPreparingShare = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("1日の利用時間の上限")
                .font(.headline)

            HStack {
                TextField("分", text: $inputMinutes)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                Text("分 / 日")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            Button("保存") {
                if let m = Int(inputMinutes), m >= 0 {
                    store.rule = Rule(dailyLimitMinutes: m)
                }
            }
            .buttonStyle(.borderedProminent)

            if store.rule.dailyLimitMinutes > 0 {
                Text("現在の設定: 1日 \(store.rule.dailyLimitMinutes) 分まで")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if store.rule.dailyLimitMinutes > 0 {
                Button {
                    isPreparingShare = true
                    store.prepareShareURL { url in
                        isPreparingShare = false
                        shareItem = url.map { IdentifiableURL(url: $0) }
                    }
                } label: {
                    if isPreparingShare {
                        ProgressView()
                    } else {
                        Label("子どもと共有", systemImage: "square.and.arrow.up")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isPreparingShare)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            if store.rule.dailyLimitMinutes > 0 {
                inputMinutes = "\(store.rule.dailyLimitMinutes)"
            }
        }
        .sheet(item: $shareItem) { identifiable in
            ShareSheet(url: identifiable.url) { shareItem = nil }
        }
    }
}

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareSheet: View {
    let url: URL
    var onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("このリンクを子どもの端末で開くと、ルールが共有されます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                ShareLink(
                    item: url,
                    subject: Text("ChildGuard のルール"),
                    message: Text("ルールを共有します")
                )
                Spacer()
            }
            .navigationTitle("子どもと共有")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ChildModeView: View {
    @ObservedObject var store: RuleStore
    @State private var authStatus: AuthorizationStatus = .notDetermined
    @State private var isRequestingAuth = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("子モード")
                .font(.headline)

            switch authStatus {
            case .notDetermined, .denied:
                Text("利用時間の制限を使うには、保護者による管理の許可が必要です。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button {
                    requestAuthorization()
                } label: {
                    if isRequestingAuth {
                        ProgressView()
                    } else {
                        Text("保護者による管理を許可する")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRequestingAuth)
            case .approved:
                childModeContent
            @unknown default:
                childModeContent
            }

            Spacer()
        }
        .onAppear {
            authStatus = AuthorizationCenter.shared.authorizationStatus
        }
    }

    private var childModeContent: some View {
        Group {
            if store.rule.dailyLimitMinutes > 0 {
                Text("1日の利用時間の上限: \(store.rule.dailyLimitMinutes) 分")
                    .font(.body)
                    .padding()
            } else {
                Text("いまルールは設定されていません。\n親モードで「1日の上限」を設定してください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            FamilyActivityPickerView()
            if store.rule.dailyLimitMinutes > 0 {
                Button("監視を開始") {
                    DeviceActivityMonitoring.startIfPossible(dailyLimitMinutes: store.rule.dailyLimitMinutes)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func requestAuthorization() {
        isRequestingAuth = true
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .child)
            } catch { /* ユーザーが拒否した場合など */ }
            await MainActor.run {
                isRequestingAuth = false
                authStatus = AuthorizationCenter.shared.authorizationStatus
            }
        }
    }
}

// MARK: - 制限するアプリの選択（App Group に保存）

struct FamilyActivityPickerView: View {
    @State private var selection = FamilyActivitySelection()
    @State private var savedMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("制限するアプリ・Web")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            FamilyActivityPicker(selection: $selection)
            Button("この選択を保存") {
                saveSelection()
            }
            .buttonStyle(.bordered)
            if let msg = savedMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .onAppear {
            loadSelection()
        }
        .onChange(of: selection) { _, _ in
            savedMessage = nil
        }
    }

    private func saveSelection() {
        guard let defaults = AppGroup.shared else {
            savedMessage = "App Group が利用できません"
            return
        }
        do {
            let data = try PropertyListEncoder().encode(selection)
            defaults.set(data, forKey: AppGroup.familyActivitySelectionKey)
            defaults.synchronize()
            savedMessage = "保存しました（制限時にこの選択が使われます）"
        } catch {
            savedMessage = "保存に失敗: \(error.localizedDescription)"
        }
    }

    private func loadSelection() {
        guard let defaults = AppGroup.shared,
              let data = defaults.data(forKey: AppGroup.familyActivitySelectionKey),
              let decoded = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) else { return }
        selection = decoded
    }
}

// Preview で ContentView をそのまま描画するとクラッシュすることがあるため、キャンバス用は簡易表示にしている。実機・シミュレータは ⌘R で起動して確認。
#Preview {
    Text("ChildGuard")
        .padding()
}
