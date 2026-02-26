//
//  ContentView.swift
//  ChildGuard
//
//  親モード / 子モード の切り替え（1本のアプリで対応）
//

import SwiftUI

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

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("子モード")
                .font(.headline)

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

            Spacer()
        }
    }
}

// Preview で ContentView をそのまま描画するとクラッシュすることがあるため、キャンバス用は簡易表示にしている。実機・シミュレータは ⌘R で起動して確認。
#Preview {
    Text("ChildGuard")
        .padding()
}
