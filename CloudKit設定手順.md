# ChildGuard：Xcode で iCloud（CloudKit）を有効にする手順

「子どもと共有」で共有リンクを出すには、アプリに **iCloud の CloudKit** を有効にする必要があります。  
**どこで何を選ぶか**を手順にしました。

---

## 1. プロジェクトを開く

- **ChildGuard.xcodeproj** を Xcode で開く（`ChildGuard/ChildGuard.xcodeproj`）。

---

## 2. ターゲットを選ぶ

- 左の **プロジェクトナビゲータ**（ファイル一覧）で、一番上の **青いプロジェクト名「ChildGuard」** をクリック。
- 中央の **TARGETS** 一覧から **「ChildGuard」**（アプリ本体。Extension ではない方）をクリック。

---

## 3. Signing & Capabilities を開く

- 画面上部のタブで **「Signing & Capabilities」** をクリック。
- まだ **「+ Capability」** ボタンが表示されていることを確認。

---

## 4. iCloud を追加する

- **「+ Capability」** ボタンをクリック。
- 一覧から **「iCloud」** を探してダブルクリック（または選択して Enter）。
- すると、Signing & Capabilities の画面に **「iCloud」** のブロックが追加される。

---

## 5. CloudKit にチェックを入れる

- 追加された **iCloud** のブロック内で、**「CloudKit」** の左のチェックボックスにチェックを入れる。
- （iCloud Documents はオフのままでよい。）

---

## 6. コンテナを選ぶ（または作る）

- **CloudKit** の下に **「Containers:」** という行がある。
- その下の **「+」** ボタン（またはコンテナ一覧の下の「＋」）をクリック。
- 次のどちらかになる：
  - **既に一覧にある場合**: **「iCloud.com.yoshi.ChildGuard」** を選択して OK。
  - **一覧にない場合**: **「Use custom container」** などを選び、**「iCloud.com.yoshi.ChildGuard」** と入力して OK（新規作成）。

これで **CloudKit にチェック** と **コンテナ iCloud.com.yoshi.ChildGuard の選択（または作成）** ができています。

---

## 7. 保存してビルド

- **⌘B** でビルド。エラーがなければ **Product → Clean Build Folder** のあと、実機で実行して「子どもと共有」を再度試す。

---

## 「子どもと共有」が動く仕組み（カスタムゾーン）

CloudKit では **共有（CKShare）は「カスタムゾーン」でしか使えません**。既定ゾーンでは「Shares cannot exist in the default zone」となり、共有リンクを作れません。  
このアプリでは **ChildGuardRules** というカスタムゾーンを使い、その中に **Rule** レコードを置いて共有しています。初回はゾーン作成 → レコード保存 → 共有作成の順で実行されます。

---

## 「読み込みエラー: CKErrorDomain error 15」と出る場合（根本でやりがちなミス）

**エラー15** は CloudKit の「サーバーがリクエストを拒否」です。**よくある根本原因**は次の 2 つです。

### 原因 1：スキーマが Development に無い（いちばん多い）

**Xcode で Run して実機で動かしているとき、CloudKit は必ず「Development」環境を使います。**  
Console で **Rule** を追加・保存するときに **「Production」側だけ** に保存していると、Development にはスキーマが無いため、サーバーがリクエストを拒否してエラー15になります。

**やること：**
1. **[CloudKit Console](https://icloud.developer.apple.com/)** を開く。
2. コンテナ **iCloud.com.yoshi.ChildGuard** を選択。
3. **Schema** → **Record Types** を開く。
4. **画面上で「Development」が選ばれているか確認する**（環境切り替えのドロップダウンやタブがよく右上や Schema の近くにあります）。**Development を選んでから** 次を実行する。
5. **Rule** が無ければ **+** で追加。**Rule** の **Fields** に **dailyLimitMinutes**（Type: Int64）を追加。
6. **Save** する（Development のまま保存すること）。
7. 実機で「子どもと共有」を再度試す。

### 原因 2：アプリに CKSharingSupported が無い

CloudKit 共有を使うアプリには、Info.plist に **CKSharingSupported = YES** が必要です。  
このプロジェクトでは Xcode のビルド設定（INFOPLIST_KEY_CKSharingSupported）で追加してあります。別プロジェクトからコピーした場合など、設定が外れていないか確認してください。

### その他

- **まず**: しばらく（数分）待ってから「子どもと共有」を**もう一度**タップする。アプリ側で 1 回だけ自動リトライ（2秒後）も入れてある。
- **iCloud の状態**: [Apple システムステータス](https://www.apple.com/jp/support/systemstatus/) で iCloud に障害が出ていないかも確認する。

---

## まとめ（どこで何をするか）

| どこ | 何をする |
|------|----------|
| 左：プロジェクト名「ChildGuard」 | クリックしてプロジェクトを選択 |
| 中央：TARGETS の「ChildGuard」 | アプリのターゲットを選択 |
| 上：タブ「Signing & Capabilities」 | クリックして開く |
| 「+ Capability」 | クリック → 一覧から「iCloud」を追加 |
| iCloud ブロック内「CloudKit」 | チェックを入れる |
| CloudKit の下「Containers」の「+」 | クリック → 「iCloud.com.yoshi.ChildGuard」を選択または新規作成 |

---

## 「ルールをQRで表示」で子の端末からアプリを開く場合（URL スキーム）

CloudKit が使えないときの代替で、親が「ルールをQRで表示」の QR を出し、子がそれを読み取ってルールを反映できます。**子の端末で QR を読み取ったときに ChildGuard が起動する**ようにするには、次の設定が必要です。

1. Xcode で **TARGETS → ChildGuard**（アプリ本体）を選択。
2. 上端の **「Info」** タブをクリック。
3. **「URL Types」** の行を探す（なければ **「+」** で **URL Types** を追加）。
4. **URL Types** の左の三角を開き、その中の項目を選択するか、下の **「+」** で 1 つ追加。
5. 追加した URL Type で次を設定する：
   - **Identifier**: 例 `com.yoshi.ChildGuard.rule`
   - **URL Schemes**: `childguard`（1 つだけ）
   - **Role**: Editor
6. 保存してビルド（⌘B）。

これで、子が `childguard://rule?minutes=60` のような QR を読み取ると ChildGuard が開き、ルールが反映されます。
