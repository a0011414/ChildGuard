# ChildGuard App（iOS）

親子で決めたルールに従い、制限・通知するアプリ。1本のアプリで親モード／子モードを切り替える。

## いま入っているもの

- **ChildGuardApp.swift** … アプリのエントリポイント（@main）
- **ContentView.swift** … 親/子モードのセグメント切り替え ＋ 各モードのプレースホルダー画面

## Xcode で開く手順（軽く始める用）

1. **Xcode** を開く
2. **File → New → Project**
3. **iOS → App** を選択
   - Product Name: `ChildGuard`（任意）
   - Interface: **SwiftUI**
   - Language: **Swift**
   - 保存場所: この `ChildGuard` フォルダの**ひとつ上**（VariousPrograms）か、この中（ChildGuardApp と並ぶ場所）で OK
4. プロジェクトができたら、**この ChildGuardApp フォルダ内の .swift ファイル**をプロジェクトにドラッグ＆ドロップで追加
5. 既存の `*App.swift` がある場合は削除するか、**ターゲットの Main Interface を ChildGuardApp に**する（エントリポイントが @main のファイル1つだけになるように）
6. **シミュレータ**で Run（⌘R）

これで「親」「子」のセグメントだけある画面がシミュレータで動きます。

## CloudKit を有効にする（ルールの iCloud 同期）

ルールを CloudKit で保存・同期するには、Xcode で次を設定してください。

1. プロジェクトを開き、**ターゲット ChildGuard** を選択
2. **Signing & Capabilities** タブを開く
3. **+ Capability** をクリック
4. **iCloud** を選んで追加
5. **CloudKit** にチェックを入れ、**Containers** で **iCloud.$(CFBundleIdentifier)** を選ぶ（または新規作成）
6. シミュレータで試す場合は、シミュレータに **Apple ID でサインイン**（設定 → サインイン）しておく

未設定のままでもアプリは動きます（UserDefaults のみ使用）。iCloud に未サインインの場合は CloudKit はスキップされ、ローカルのみ保存されます。

## 親→子共有の流れ

1. **親**: ルールを保存し、親モードで「子どもと共有」をタップ → 共有用 URL が用意され、ShareLink でメールやメッセージ等に送れる。
2. **子**: その URL を自分の iPhone で開く（同じアプリが入っていること）→ 共有を承諾すると、ルールが子のアプリに反映される。

## 参照

- 要件・技術方針: ひとつ上のフォルダの `要件メモ.md` `技術メモ.md` `実装前チェック.md`
