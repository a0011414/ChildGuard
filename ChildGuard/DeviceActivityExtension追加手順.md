# Device Activity Monitor Extension を Xcode で追加する手順

Extension のソース（`ChildGuardDeviceActivityMonitorExtension/`）はすでに用意済みです。  
Xcode で **Extension ターゲット** を追加し、このフォルダをそのターゲットに紐づけてください。

## 1. 新規ターゲットの追加

1. Xcode で **ChildGuard** プロジェクトを開く。
2. プロジェクトナビゲータでプロジェクト（青いアイコン）を選択。
3. 下部の **TARGETS** で **+** をクリック。
4. **iOS** → **Device Activity Monitor Extension** を選び **Next**。
5. **Product Name**: `ChildGuardDeviceActivityMonitorExtension`  
   **Bundle Identifier**: `com.yoshi.ChildGuard.DeviceActivityMonitor`（自動入力ならそのまま）  
   **Language**: Swift  
   → **Finish**。
6. 「Activate "ChildGuardDeviceActivityMonitorExtension" scheme?」→ **Cancel**（メインアプリの scheme のままにする）。

## 2. 生成されたファイルの差し替え

1. Xcode が自動で作った **DeviceActivityMonitorExtension** 用のフォルダ／ファイルを削除（または中身を空に）。
2. プロジェクトに **ChildGuardDeviceActivityMonitorExtension** フォルダを追加する。  
   **File → Add Files to "ChildGuard"** で、  
   `ChildGuard/ChildGuardDeviceActivityMonitorExtension` フォルダを選ぶ。  
   **Copy items if needed** はオフ、**Add to targets** で **ChildGuardDeviceActivityMonitorExtension** にだけチェックを入れる。
3. **Info.plist** も同じターゲットに追加する（Build Phases → Copy Bundle Resources に Info.plist が含まれるようにする。または Target の Info で Custom iOS Target Properties にこの Info.plist を指定）。

## 3. Extension ターゲットの設定

1. **TARGETS** で **ChildGuardDeviceActivityMonitorExtension** を選択。
2. **Signing & Capabilities**  
   - **+ Capability** → **App Groups** を追加。  
   - `group.com.yoshi.ChildGuard` にチェック（メインアプリと同じ）。
   - **+ Capability** → **Family Controls** を追加（まだなら）。
3. **Build Settings**  
   - **Code Signing Entitlements**: Extension 用の entitlements を用意する場合、そのパスを指定。  
     （App Groups と Family Controls だけなら、Xcode が自動で entitlements を生成する場合もある。）
4. **Build Phases**  
   - **Compile Sources** に `DeviceActivityMonitorExtension.swift` が入っていることを確認。

## 4. メインアプリから Extension を埋め込む

1. **TARGETS** で **ChildGuard**（メインアプリ）を選択。
2. **Build Phases** → **+** → **Embed Foundation Extensions**。
3. 一覧から **ChildGuardDeviceActivityMonitorExtension.appex** を追加。

## 5. 動作確認

- **実機**でビルド・実行（Device Activity はシミュレータでは動かない場合があります）。
- 子モードで「保護者による管理を許可」→ アプリを選択して保存 → 「監視を開始」をタップ。
- 選択したアプリをしきい値（分）まで使うと、Extension の `eventDidReachThreshold` が呼ばれ、シールドがかかる想定です。

---

問題があれば、Extension の Bundle ID や App Group がメインアプリと一致しているか、Family Controls の Capability が両方のターゲットで有効かを確認してください。
