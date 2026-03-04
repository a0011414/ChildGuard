//
//  ContentView.swift
//  ChildGuard
//
//  親モード / 子モード の切り替え（1本のアプリで対応）
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
                .id(mode)
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
    @State private var isParentDevice: Bool = false
    @State private var inputMinutes: String = ""
    @State private var shareItem: IdentifiableURL?
    @State private var isPreparingShare = false
    @State private var parentNotifyBaseURL: String = ""
    @State private var displayedFamilyId: String?
    @State private var parentRegisterMessage: String?
    @State private var isRegisteringParent = false
    @State private var showQRScanner = false
    @State private var showQRDisplay = false
    @State private var showFamilyCodeQR = false
    @State private var showFCMURLDetails = false
    @State private var scrollContentId = 0
    @State private var shareErrorMessage: String?
    /// CloudKit が使えないとき用：ルールを childguard:// の QR で表示
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

            if isParentDevice {
                // 親用端末: 編集・保存・共有・FCM 設定
                parentDeviceContent
            } else {
                // 子の端末など: 表示のみ ＋ この端末を親用として登録するボタン
                nonParentDeviceContent
            }
        }
        .padding(.bottom, 24)
        }
        .id(scrollContentId)
        .padding()
        .onAppear {
            isParentDevice = UserDefaults.standard.bool(forKey: AppGroup.isParentDeviceKey)
            if store.rule.dailyLimitMinutes > 0 {
                inputMinutes = "\(store.rule.dailyLimitMinutes)"
            }
            let saved = AppGroup.shared
            parentNotifyBaseURL = saved?.string(forKey: AppGroup.parentNotifyBaseURLKey) ?? AppGroup.defaultFCMBaseURL
            displayedFamilyId = saved?.string(forKey: AppGroup.familyIdKey)
        }
        .sheet(isPresented: $showQRScanner, onDismiss: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { scrollContentId += 1 }
        }) {
            QRCodeScannerView(scannedURL: $parentNotifyBaseURL)
        }
        .sheet(isPresented: $showQRDisplay, onDismiss: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { scrollContentId += 1 }
        }) {
            QRCodeDisplayView(urlString: parentNotifyBaseURL)
        }
        .sheet(isPresented: $showFamilyCodeQR, onDismiss: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { scrollContentId += 1 }
        }) {
            FamilyCodeQRSheetView(familyCode: displayedFamilyId ?? "")
        }
        .sheet(item: $shareItem) { identifiable in
            ShareSheet(url: identifiable.url) { shareItem = nil }
        }
    }

    /// 親用端末として登録済みのときの UI（編集・保存・共有・FCM）
    @ViewBuilder
    private var parentDeviceContent: some View {
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
                Button {
                    shareErrorMessage = nil
                    isPreparingShare = true
                    store.prepareShareURL { url, errorMessage in
                        isPreparingShare = false
                        if let url = url {
                            shareItem = IdentifiableURL(url: url)
                        } else {
                            shareErrorMessage = errorMessage ?? "共有リンクを用意できませんでした。iCloud にサインインしているか、しばらく待ってから再度お試しください。"
                            showRuleQRSheet = true
                        }
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
                if let msg = shareErrorMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                Button("ルールをQRで表示（CloudKitが使えないとき）") {
                    showRuleQRSheet = true
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            .sheet(isPresented: $showRuleQRSheet) {
                RuleQRSheet(minutes: store.rule.dailyLimitMinutes)
            }
        }

        Divider()
            .padding(.vertical, 8)

        Text("親への通知（FCM）")
            .font(.headline)
        Text("上の「子どもと共有」のQRはルール用。ここは制限がかかったときの通知先の識別用です。この端末を「親」として登録すると、子の制限到達時にプッシュが届きます。家族コードを子の端末で入力するかQRで読み取らせてください。")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

        if let code = displayedFamilyId {
            Text("家族コード: \(code)")
                .font(.title3.monospacedDigit())
            Button("QRで表示（子がスキャン）") {
                showFamilyCodeQR = true
            }
            .buttonStyle(.bordered)
            Button("トークンを再登録") {
                registerParent()
            }
            .buttonStyle(.bordered)
            .disabled(isRegisteringParent)
        } else {
            Button("親としてこの端末を登録") {
                registerParent()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRegisteringParent)
        }
        if isRegisteringParent {
            ProgressView()
        }
        if let msg = parentRegisterMessage {
            Text(msg)
                .font(.caption)
                .foregroundStyle(msg.hasPrefix("登録しました") ? Color.secondary : Color.red)
                .multilineTextAlignment(.center)
        }

        DisclosureGroup("URL（詳細）") {
            Text(effectiveFCMBaseURL)
                .font(.caption2)
                .textSelection(.enabled)
            TextField("上書きする場合のみ入力", text: $parentNotifyBaseURL)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .font(.caption)
        }
        .padding(.top, 4)
    }

    private var effectiveFCMBaseURL: String {
        let s = parentNotifyBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? AppGroup.defaultFCMBaseURL : s
    }

    /// 親用端末未登録のときの UI（表示のみ ＋ この端末を親用として登録する）
    @ViewBuilder
    private var nonParentDeviceContent: some View {
        if store.rule.dailyLimitMinutes > 0 {
            Text("現在の設定: 1日 \(store.rule.dailyLimitMinutes) 分まで")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        } else {
            Text("いまルールは設定されていません。\n親用の端末で「1日の上限」を設定し、子どもと共有してください。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)
        }

        Text("設定の変更は、親用として登録した端末でのみ行えます。")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

        Button {
            registerAsParentDevice()
        } label: {
            if isRegisteringParent {
                ProgressView()
            } else {
                Label("この端末を親用として登録する", systemImage: "person.badge.plus")
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isRegisteringParent)
        .padding(.top, 8)
        if let msg = parentRegisterMessage {
            Text(msg)
                .font(.caption)
                .foregroundStyle(msg.hasPrefix("登録しました") ? Color.secondary : Color.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    /// この端末を「親用」として登録し、FCMで家族コードを取得する
    private func registerAsParentDevice() {
        UserDefaults.standard.set(true, forKey: AppGroup.isParentDeviceKey)
        isParentDevice = true
        registerParent()
    }

    private func registerParent() {
        parentRegisterMessage = nil
        isRegisteringParent = true
        let baseURL = effectiveFCMBaseURL
        let existingId = displayedFamilyId
        Task {
            let result = await ParentNotificationService.registerAsParent(baseURL: baseURL, existingFamilyId: existingId)
            await MainActor.run {
                isRegisteringParent = false
                switch result {
                case .success(let familyId):
                    displayedFamilyId = familyId
                    parentRegisterMessage = "登録しました。家族コード: \(familyId)。子の端末でこのコードを入力するか、QRで読み取ってください。"
                case .failure(let error):
                    parentRegisterMessage = error.message
                }
            }
        }
    }
}

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

/// CloudKit を使わず、ルールを childguard://rule?minutes=... の QR で渡す用
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

private struct ShareSheet: View {
    let url: URL
    var onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("子どもの端末でこのQRを読み取ると、ルールが共有されます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                if let image = qrImage {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260, maxHeight: 260)
                }
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

    private var qrImage: UIImage? {
        let s = url.absoluteString
        guard !s.isEmpty, let data = s.data(using: .utf8) else { return nil }
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
    @State private var familyCodeInput: String = ""
    @State private var familyCodeSavedMessage: String?
    @State private var showFamilyCodeQRScanner = false
    /// シート閉じ後などにスクロールがおかしくなるのを防ぐため、ID で再描画する
    @State private var scrollContentId = 0

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
            familyCodeInput = AppGroup.shared?.string(forKey: AppGroup.familyIdKey) ?? ""
        }
        .alert("認可エラー", isPresented: Binding(get: { authErrorMessage != nil }, set: { if !$0 { authErrorMessage = nil } })) {
            Button("OK", role: .cancel) { authErrorMessage = nil }
        } message: {
            if let msg = authErrorMessage { Text(msg) }
        }
        .sheet(isPresented: $showFamilyCodeQRScanner, onDismiss: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                scrollContentId += 1
            }
        }) {
            QRCodeScannerView(scannedURL: $familyCodeInput, acceptAnyString: true)
        }
    }

    @ViewBuilder
    private var childModeContent: some View {
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

        // アプリ選択を確実に表示（高さを確保してスクロールで届くようにする）
        FamilyActivityPickerView()
            .frame(minHeight: 240)

        Text("家族コード（8桁）")
            .font(.caption)
            .foregroundStyle(.secondary)
        Text("親の端末で表示されている8桁のコードを入力するか、QRで読み取ると、制限がかかったときにその親にプッシュが届きます。")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        HStack {
            TextField("12345678", text: $familyCodeInput)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .font(.body.monospacedDigit())
            Button("QRで読み取る") {
                showFamilyCodeQRScanner = true
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        HStack {
            Button("保存") {
                let raw = familyCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
                let digits = raw.filter(\.isNumber)
                if digits.count == 8 {
                    AppGroup.shared?.set(digits, forKey: AppGroup.familyIdKey)
                    if AppGroup.shared?.string(forKey: AppGroup.parentNotifyBaseURLKey) == nil {
                        AppGroup.shared?.set(AppGroup.defaultFCMBaseURL, forKey: AppGroup.parentNotifyBaseURLKey)
                    }
                    familyCodeSavedMessage = "保存しました"
                } else if raw.isEmpty {
                    AppGroup.shared?.removeObject(forKey: AppGroup.familyIdKey)
                    familyCodeSavedMessage = "家族コードを削除しました"
                } else {
                    familyCodeSavedMessage = "8桁の数字を入力してください"
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        if let msg = familyCodeSavedMessage {
            Text(msg)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }

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
