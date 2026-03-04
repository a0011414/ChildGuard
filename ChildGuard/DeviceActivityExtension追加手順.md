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

**重要**: Extension の `ChildGuardDeviceActivityMonitorExtension.entitlements` の **App Groups の配列が空でないこと**。`group.com.yoshi.ChildGuard` が含まれていないと、Extension から本体が保存した選択を読めず「シールドをかけられませんでした」になる。

---

## Family Controls (Distribution) の申請が必要な場合

**メッセージ例**  
`Bundle identifier is using development only version of Family Controls (Development) capability. Please request access to Family Controls (Distribution) to avoid issues when distributing.`

**意味**  
いま使っているのは **Family Controls (Development)** だけです。**TestFlight や App Store に配布するには、別途「Family Controls (Distribution)”の申請と承認**が必要です。

**やること**

1. **配布用の申請フォーム**を開く（Apple Developer にログインした状態で）。  
   **https://developer.apple.com/contact/request/family-controls-distribution**
2. フォームの指示に従い、**メインアプリ**（Bundle ID: `com.yoshi.ChildGuard`）について申請する。
3. **Extension**（Bundle ID: `com.yoshi.ChildGuard.ChildGuardDeviceActivityMonitorExtension`）も Family Controls を使うため、フォームで「複数 Bundle ID」を指定できる場合は Extension も含める。できない場合は、同じフォームの備考に Extension の Bundle ID を書くか、**別途もう 1 件申請**する（Apple の案内により異なります）。
4. 審査は **数週間**かかることが多いです。承認されるとメールで連絡があり、Developer 側で該当 Bundle ID に Family Controls (Distribution) が有効になります。その後、プロファイルを作り直すか Xcode で再 Archive すると、配布用の entitlement が付きます。

くわしい記入例・申請の流れは、プロジェクト直下の **申請メモ.md** を参照してください。

---

## トラブルシューティング：Provisioning profile に Family Controls が含まれない

**エラー例**  
- `… doesn't include the Family Controls (Development) capability.`  
- `… doesn't include the com.apple.developer.family-controls entitlement.`  

（いずれも同じ原因です。）

**原因**  
Extension 用の **App ID**（`com.yoshi.ChildGuard.ChildGuardDeviceActivityMonitorExtension`）に、Apple Developer 側で **Family Controls** が有効になっていないため、作られる Provisioning Profile にその権限（entitlement）が入っていません。

**対処手順**

### A. Xcode で Extension ターゲットに Family Controls が付いているか確認

1. **TARGETS** で **ChildGuardDeviceActivityMonitorExtension** を選択。
2. **Signing & Capabilities** タブを開く。
3. **+ Capability** で **Family Controls** が追加されているか確認。なければ **+ Capability** → **Family Controls** を追加する。  
   （entitlements ファイルにキーがあっても、ここで Capability が付いていないと Xcode がプロファイルに entitlement を要求しないことがあります。）

### B. Apple Developer で App ID に Family Controls を付ける

**「App ID に Family Controls を付ける」とは何か**  
- **App ID** は、Apple に「この Bundle ID のアプリ（または Extension）はこういう権限を使う」と登録したものです。  
- その App ID の設定のなかに **Capabilities**（能力・権限の一覧）があり、ここに **Family Controls** を「使う」と宣言しておく必要があります。  
- 宣言していないと、その App ID 用に発行される **Provisioning Profile** に Family Controls が含まれず、Xcode が「このプロファイルには family-controls が入っていない」とエラーになります。  
→ なので、**Developer サイトで「Extension 用の App ID」を開き、Capabilities の一覧で Family Controls にチェックを入れて保存する**のが「App ID に Family Controls を付ける」操作です。

**操作手順（developer.apple.com の画面で）**

1. ブラウザで **https://developer.apple.com/account** を開き、Apple Developer の Apple ID でログインする。
2. **Certificates, Identifiers & Profiles** のエリアを開く（トップのカードの一つ、または左サイドバーのリンク）。
3. 左または一覧から **Identifiers** をクリックする。
4. **App IDs** が選ばれた状態で、一覧から **com.yoshi.ChildGuard.ChildGuardDeviceActivityMonitorExtension** を探し、その行をクリックして開く。  
   （一覧では **Name** が「ChildGuard Extension」などと表示されていることがあります。その行でよい。）  
   - 一覧にない場合は **+**（新規）をクリック → **App** を選ぶ → **Description** と **Bundle ID** に `com.yoshi.ChildGuard.ChildGuardDeviceActivityMonitorExtension` を入力して **Continue** → **Register** で作成し、作成されたものを開く。
5. 開いた画面で **Capabilities** のセクションまで下にスクロールする。チェックボックスがたくさん並んでいる一覧（App Groups, Associated Domains, … **Family Controls**, …）がある。
6. その一覧で **Family Controls** にチェックを入れる。
7. 画面右上または下の **Save** をクリックして保存する。

### C. Xcode でプロファイルを更新してから再アーカイブ

（Developer で App ID に Family Controls を付けたあと、または **すでに Family Controls にチェックが入っている**場合でも、Xcode が古い Provisioning Profile をキャッシュしているとエラーが出ることがあります。そのときは以下で「新しいプロファイルを使う」ようにします。）

1. **Xcode** に戻る。
2. **Product → Clean Build Folder**（Shift + Cmd + K）を実行する。
3. **Xcode → Settings → Accounts** → 該当 Apple ID を選び **Download Manual Profiles** をクリックする。
4. 再度 **Product → Archive** を試す。  
   （自動署名なら）Xcode が Family Controls 付きの新しい Provisioning Profile を取得し、ビルドできるようになります。

まだ同じエラーになる場合：**Signing & Capabilities**（Extension ターゲット）で「Automatically manage signing」を一度オフにしてから再度オンにすると、プロファイルが作り直されることがあります。

### まだエラーが出る場合：古い Distribution プロファイルを削除する

（Download Manual Profiles や自動署名の切り直しでも直らないときは、**Archive 時に使っている Distribution 用プロファイル**が古いまま使われています。Developer サイトの一覧に該当プロファイルがある場合はそこで削除し、**一覧に何も出てこない／該当が無い**場合は、Mac 内の「ローカルに保存されているプロファイル」を削除します。）

**方法 A：Developer サイトのプロファイル一覧に該当がある場合**

1. ブラウザで **https://developer.apple.com/account** → **Certificates, Identifiers & Profiles** → **Profiles** を開く。
2. 一覧（**All** や **Distribution** などでフィルタを変えてみる）から **iOS Team Store Provisioning Profile: com.yoshi.ChildGuard.ChildGuardDeviceActivityMonitorExtension** を探す。  
   （Identifier が `com.yoshi.ChildGuard.ChildGuardDeviceActivityMonitorExtension` の **App Store Connect** 用のものを選ぶ。）
3. そのプロファイルをクリックして開き、**Delete**（削除）を実行する。
4. 以下「共通」の 4〜5 を行う。

**方法 B：プロファイル一覧に何も出てこない／該当プロファイルが無い場合**

（Xcode が自動で作ったプロファイルは Developer サイトの一覧に出ないことがあります。その場合は **Mac 内のプロファイル保存フォルダ**から、Extension 用の古いプロファイルだけ削除します。）

1. **Finder** を開く。
2. メニュー **移動** で **フォルダへ移動**（Shift + Cmd + G）を選び、次のパスを入力して **移動** する。  
   `~/Library/MobileDevice/Provisioning Profiles`
3. フォルダ内の **.mobileprovision** ファイルが一覧表示される。一つずつ **ダブルクリック** すると、プロファイルの内容が別ウィンドウで開く。
4. そのウィンドウに **ChildGuardDeviceActivityMonitorExtension** や **com.yoshi.ChildGuard.ChildGuardDeviceActivityMonitorExtension** と書いてあるものを探す。見つかったら、その **.mobileprovision** ファイルを **ゴミ箱に移動**（削除）する。
5. 以下「共通」の 4〜5 を行う。

**方法 C：プロファイル用フォルダが空の場合**

（`~/Library/MobileDevice/Provisioning Profiles` に .mobileprovision が一つも無い場合。**Developer サイトで Extension 用の Distribution プロファイルを手動で新規作成**し、Xcode でそのプロファイルだけ「手動」で指定する。）

---

**▼ 現在地と流れ（どこまで戻るか）**

| やること | 状態 |
|----------|------|
| App ID（ChildGuard Extension）に Family Controls を付ける | ✅ 済み |
| プロファイルを「手動で新規作成」する | 🔲 ここで止まっている |
| → その途中の「証明書を選ぶ」画面で **No Certificates are available** と出る | ← いまここ |
| 理由 | 持っている証明書は「Distribution Managed」で、**Web のプロファイル作成では選べない**。 |
| **次にやること** | **いったんプロファイル作成はやめる。先に「CSR で作る Apple Distribution 証明書」を 1 本作る。** 作ったあと、下の 1 からやり直し、証明書を選ぶところでその証明書を選ぶ。 |

---

**▼ 先にやる：証明書を 1 本作る（CSR をアップロードする）**

（キーチェーンアクセスが無くても、**ターミナルで OpenSSL** を使って CSR を作れます。）

1. **ターミナル**を開く（アプリケーション → ユーティリティ → **ターミナル**、または Spotlight で「ターミナル」と検索）。
2. 作業用フォルダに移動する（例: デスクトップ）。  
   `cd ~/Desktop`
3. 秘密鍵を作る。  
   `openssl genrsa -out AppleDistribution.key 2048`
4. CSR を作る（メールと名前は自分のものに書き換える）。  
   `openssl req -new -key AppleDistribution.key -out request.certSigningRequest -subj "/emailAddress=あなたのメール@example.com/CN=Yoshiaki Uchida/C=JP"`
5. ブラウザで **https://developer.apple.com/account** → **Certificates, Identifiers & Profiles** → **Certificates** を開く。
6. **+** をクリック → **Apple Distribution** を選んで **Continue**。
7. **Choose File** で、ターミナルで作った **request.certSigningRequest**（デスクトップにある）を選んでアップロード → **Continue** → **Download** で .cer を保存する。
8. ダウンロードした **.cer** をダブルクリックして、キーチェーンにインストールする。
9. **秘密鍵をキーチェーンに入れる**（証明書とペアにする）。ターミナルで次を実行（パスワードを聞かれたら Mac のログインパスワード）。  
   `security import ~/Desktop/AppleDistribution.key -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign -T /usr/bin/security -A`  
   これで「証明書を選ぶ」一覧に新しい証明書が表示されるようになります。

**証明書が「ダウンロードできない」とき**

- **Distribution Managed** や **Xcode Cloud** の証明書は、Apple の仕様で **Download が出ません**（Xcode が管理しているため）。プロファイル作成で「証明書を選ぶ」にも出ないので、**CSR で新規作成した証明書**が必要です。
- **CSR で作った証明書**は、**作成が終わった直後の画面**に **Download** があります。ここで .cer を保存する。  
  その画面を閉けてしまった場合：**Certificates** 一覧でその証明書の**名前をクリック**して詳細を開き、**Download** のリンクがあるか確認。無い場合は「作成直後にしかダウンロードできない」ことがあるので、その証明書を **Revoke**（無効化）してから、もう一度 CSR で新規作成し、**作成直後に必ず Download** する。

**プロファイルが「ダウンロードできない」とき**

- **Profiles** 一覧で、作ったプロファイルの**名前（行）をクリック**して詳細を開く。詳細画面に **Download** ボタンがあります。一覧の行だけだと Download が出ないことがあります。

**プロファイルに「Family Controls が含まれていない」と出るとき**

1. **App ID の確認**  
   **Identifiers** → **ChildGuard Extension**（`com.yoshi.ChildGuard.ChildGuardDeviceActivityMonitorExtension`）を開く。**Capabilities** で **Family Controls**（または **Family Controls (Development)**）にチェックが入っているか確認。入っていなければチェックして **Save**。

2. **古いプロファイルを Mac から消す**  
   Finder で **移動 → フォルダへ移動**（Shift + Cmd + G）→ `~/Library/MobileDevice/Provisioning Profiles` を開く。  
   中にある **.mobileprovision** を一つずつダブルクリックして内容を確認し、**ChildGuard** や **ChildGuardDeviceActivityMonitorExtension** 用のものを **ゴミ箱に移動**する（全部削除してもよい）。これで「古いプロファイル」が Xcode に選ばれなくなります。

3. **Developer サイトでプロファイルを作り直す**  
   **Profiles** で「ChildGuard Extension AppStore」を開く → **Delete**。  
   続けて **+** で新規作成：**Distribution** → **App Store Connect** → **App ID: ChildGuard Extension** → **Certificate: 今使っている証明書** → **Profile Name**: `ChildGuard Extension AppStore` → **Generate**。  
   作成されたプロファイルの **Download** をクリックし、.mobileprovision を保存する。

4. **新しいプロファイルだけをインストールする**  
   ダウンロードした .mobileprovision を **ダブルクリック** してインストール（手順 2 で古いものを消しているので、これだけが残る）。

5. **Xcode** で Extension ターゲットの **Signing & Capabilities** を開き、**Provisioning Profile** で「ChildGuard Extension AppStore」を選び直す。**Product → Clean Build Folder** のあと **Product → Archive**。

※ それでも同じエラーになる場合、**Identifiers** の **ChildGuard Extension** の **Capabilities** 一覧に **Family Controls** がそもそも表示されていないことがあります。その場合は Family Controls の利用申請がアカウントで承認されているか、Developer サポートに確認してください。

---

**▼ 証明書ができたら：プロファイルを新規作成する（1 からやり直し）**

1. ブラウザで **Certificates, Identifiers & Profiles** → **Profiles** を開く。
2. **+** または **Register a New Provisioning Profile** をクリックする。
3. **Distribution** の **App Store Connect** を選んで **Continue**。
4. **App ID** のドロップダウンから **ChildGuard Extension** を選び **Continue**。
5. **Certificate** の画面で、**今作った証明書**（一覧に表示されているもの）を **1 つ選んで Continue** する。
6. **Profile Name** に名前（例: `ChildGuard Extension AppStore`）を入力し **Generate**（または **Register**）をクリックする。
7. 作成されたプロファイルの **Download** をクリックし、.mobileprovision を Mac に保存する。ダウンロードしたファイルを **ダブルクリック** してインストール（Xcode が認識する）しておく。
8. **Xcode** を開き、**TARGETS** で **ChildGuardDeviceActivityMonitorExtension** を選択 → **Signing & Capabilities** タブを開く。
9. **Automatically manage signing** のチェックを **外す**。
10. **Provisioning Profile** のドロップダウンで、手順 7 でダウンロードしたプロファイル（例: ChildGuard Extension AppStore）を選ぶ。
11. **Product → Clean Build Folder** のあと **Product → Archive** を実行する。

（ここまでで、Extension 用の手動プロファイル設定は完了です。）

※ メインアプリの **ChildGuard** ターゲットは、これまでどおり「Automatically manage signing」のままでもかまいません。Extension ターゲットだけ手動でこのプロファイルを指定します。

**共通（A でも B でもここまでやったあと）**

4. **Xcode** で **Product → Clean Build Folder**（Shift + Cmd + K）を実行する。
5. **Product → Archive** を再度実行する。  
   → Xcode が新しい Provisioning Profile を取得（または作成）し、そのときに App ID の現在の設定（Family Controls 付き）が反映され、エラーが解消されることが多いです。

**手動で Provisioning Profile を指定している場合**  
Developer サイトの **Profiles** で、該当の **Distribution** 用プロファイルを開き **Edit** → 変更を保存してから、プロファイルを再ダウンロードし、Xcode の Signing でそのプロファイルを選び直してください。それでも entitlement が付かない場合は、上と同様にそのプロファイルを削除し、新規に **App Store Connect** 用プロファイルを作成してダウンロードし、Xcode で指定し直してください。
