//
//  ContentView.swift
//  ChildGuard
//
//  初回のみ親/子を選択。以降は選んだ方の画面のみ表示（切り替え不可）。
//

import SwiftUI
import FamilyControls
import ManagedSettings
import UserNotifications
import CoreImage.CIFilterBuiltins

enum AppMode: String, CaseIterable {
    case parent = "親"
    case child = "子"
}

struct ContentView: View {
    @EnvironmentObject var ruleStore: RuleStore
    /// 未設定なら初回選択画面、設定済みならその役割の画面のみ表示
    @State private var savedRole: AppMode?

    var body: some View {
        Group {
            if let role = savedRole {
                roleView(role)
            } else {
                RoleSelectionView { selected in
                    UserDefaults.standard.set(selected.rawValue, forKey: AppGroup.roleKey)
                    if selected == .parent {
                        UserDefaults.standard.set(true, forKey: AppGroup.isParentDeviceKey)
                    }
                    savedRole = selected
                }
            }
        }
        .onAppear {
            loadRole()
        }
    }

    private func loadRole() {
        guard let raw = UserDefaults.standard.string(forKey: AppGroup.roleKey),
              let role = AppMode(rawValue: raw) else {
            savedRole = nil
            return
        }
        savedRole = role
    }

    @ViewBuilder
    private func roleView(_ role: AppMode) -> some View {
        NavigationStack {
            Group {
                switch role {
                case .parent:
                    ParentModeView(store: ruleStore)
                case .child:
                    ChildModeView(store: ruleStore)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

/// 初回起動時のみ表示。親用 / 子用のいずれかを選ばせ、以降はその役割のみ使用する。
private struct RoleSelectionView: View {
    var onSelect: (AppMode) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Text("この端末をどちらとして使いますか？")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 16) {
                    Button {
                        onSelect(.parent)
                    } label: {
                        Label("親用として使う", systemImage: "person.2.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        onSelect(.child)
                    } label: {
                        Label("子用として使う", systemImage: "person.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 40)

                Text("一度選ぶと変更できません。別の役割で使う場合はアプリを削除して再インストールしてください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 48)
            .navigationTitle("ChildGuard")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ParentModeView: View {
    @ObservedObject var store: RuleStore
    @State private var inputMinutes: String = ""
    @State private var scrollContentId = 0
    @State private var showRuleQRSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "person.2.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                Text("1日の利用時間の上限")
                    .font(.headline)

                Button("表示がおかしいときはタップ") {
                    scrollContentId += 1
                }
                .font(.caption)
                .foregroundStyle(.secondary)

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
                    Group {
                        Text("ルールを子に渡す")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            showRuleQRSheet = true
                        } label: {
                            Label("ルールをQRで表示", systemImage: "qrcode")
                        }
                        .buttonStyle(.borderedProminent)
                        Text("子の端末でこのQRを読み取ると、ルールが反映されます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .sheet(isPresented: $showRuleQRSheet) {
                        RuleQRSheet(minutes: store.rule.dailyLimitMinutes)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .id(scrollContentId)
        .padding()
        .onAppear {
            if store.rule.dailyLimitMinutes > 0 {
                inputMinutes = "\(store.rule.dailyLimitMinutes)"
            }
        }
    }
}

/// ルールを childguard://rule?minutes=... の QR で渡す用
private struct RuleQRSheet: View {
    let minutes: Int
    @Environment(\.dismiss) private var dismiss

    private var ruleURL: URL? {
        var comp = URLComponents()
        comp.scheme = "childguard"
        comp.host = "rule"
        comp.queryItems = [URLQueryItem(name: "minutes", value: "\(minutes)")]
        return comp.url
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("子の端末でこのQRを読み取ると、ルール（1日 \(minutes) 分）が反映されます。カメラアプリやQRリーダーで読み取ってください。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                if let url = ruleURL, let image = qrImage(for: url.absoluteString) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260, maxHeight: 260)
                }
                Spacer()
            }
            .navigationTitle("ルールをQRで表示")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func qrImage(for string: String) -> UIImage? {
        guard !string.isEmpty, let data = string.data(using: .utf8) else { return nil }
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: .init(scaleX: 8, y: 8))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

struct ChildModeView: View {
    @ObservedObject var store: RuleStore
    @State private var authStatus: AuthorizationStatus = .notDetermined
    @State private var isRequestingAuth = false
    @State private var authErrorMessage: String?
    @State private var monitoringMessage: String?
    @State private var scrollContentId = 0
    @State private var showRuleQRScanner = false
    @State private var scannedRuleURL: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "person.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                Text("子モード")
                    .font(.headline)

                Button("表示がおかしいときはタップ") {
                    scrollContentId += 1
                }
                .font(.caption)
                .foregroundStyle(.secondary)

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
            }
            .padding(.bottom, 24)
        }
        .id(scrollContentId)
        .onAppear {
            authStatus = AuthorizationCenter.shared.authorizationStatus
        }
        .alert("認可エラー", isPresented: Binding(get: { authErrorMessage != nil }, set: { if !$0 { authErrorMessage = nil } })) {
            Button("OK", role: .cancel) { authErrorMessage = nil }
        } message: {
            if let msg = authErrorMessage { Text(msg) }
        }
        .sheet(isPresented: $showRuleQRScanner, onDismiss: {
            applyRuleFromScannedURLIfNeeded()
        }) {
            QRCodeScannerView(
                scannedURL: $scannedRuleURL,
                acceptAnyString: true,
                prompt: "親のiPhoneで表示したルールのQRを読み取ってください"
            )
        }
        .onChange(of: scannedRuleURL) { _, _ in
            applyRuleFromScannedURLIfNeeded()
        }
    }

    /// スキャンした文字列が childguard://rule?minutes=X ならルールを反映する
    private func applyRuleFromScannedURLIfNeeded() {
        guard let url = URL(string: scannedRuleURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "childguard",
              url.host == "rule",
              let comp = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let minutes = comp.queryItems?.first(where: { $0.name == "minutes" })?.value.flatMap(Int.init),
              minutes > 0 else { return }
        store.applyRuleFromQR(dailyLimitMinutes: minutes)
        scannedRuleURL = ""
    }

    @ViewBuilder
    private var childModeContent: some View {
        if store.rule.dailyLimitMinutes > 0 {
            Text("1日の利用時間の上限: \(store.rule.dailyLimitMinutes) 分")
                .font(.body)
                .padding()
        } else {
            Text("いまルールは設定されていません。\n親のiPhoneで「ルールをQRで表示」したQRを読み取るか、下のボタンから読み取ってください。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }

        Button {
            showRuleQRScanner = true
        } label: {
            Label("親からルールをもらう（QRを読み取る）", systemImage: "qrcode.viewfinder")
        }
        .buttonStyle(.borderedProminent)
        .padding(.bottom, 8)

        // アプリ選択を確実に表示（高さを確保してスクロールで届くようにする）
        FamilyActivityPickerView()
            .frame(minHeight: 240)

        Button("監視を開始") {
            Task {
                _ = await requestNotificationPermissionIfNeeded()
                await MainActor.run {
                    monitoringMessage = DeviceActivityMonitoring.startIfPossible(dailyLimitMinutes: store.rule.dailyLimitMinutes)
                    if monitoringMessage == nil {
                        monitoringMessage = "監視を開始しました。このあと、選んだアプリを設定分数だけ使うと制限がかかります（それ以前の利用はカウントされません）。"
                    }
                }
            }
        }
        .buttonStyle(.bordered)
        if let msg = monitoringMessage {
            Text(msg)
                .font(.caption)
                .foregroundStyle(isMonitoringSuccessMessage ? Color.secondary : Color.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var isMonitoringSuccessMessage: Bool {
        monitoringMessage?.hasPrefix("監視を開始しました") == true
    }

    /// 制限到達時に Extension から通知を出すため、本体で許可を取っておく
    private func requestNotificationPermissionIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
        return settings.authorizationStatus == .authorized
    }

    private func requestAuthorization() {
        authErrorMessage = nil
        isRequestingAuth = true
        Task {
            do {
                // .individual = この端末で Face ID / Touch ID で許可（テストや単独利用向け）
                // .child = ファミリー共有の保護者が許可（実際の子の端末向け）
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            } catch {
                await MainActor.run {
                    authErrorMessage = "許可できませんでした: \(error.localizedDescription)"
                }
            }
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
            Text("監視を開始するには「アプリ」で1つ以上選んでください。")
                .font(.caption2)
                .foregroundStyle(Color.secondary)
            FamilyActivityPicker(selection: $selection)
                .frame(minHeight: 200, maxHeight: 260)
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
