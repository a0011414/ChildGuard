# FCM で親への通知を動かす手順（子＝実機・親＝シミュレータ）

子の iPhone（実機）で制限がかかったときに、親端末（シミュレータ or 実機）に「制限がかかりました」のプッシュを送るための設定です。

---

## 次にやること（チェックリスト）

- [x] **1** Firebase プロジェクト作成 → Firestore 有効化 → iOS アプリ追加 → GoogleService-Info.plist ダウンロード＆Xcode に追加（**済**: `GoogleService-Info.plist` あり・プロジェクト `childguard-72f89`）
- [ ] **2** Cloud Messaging で APNs 認証キー（.p8）を Firebase にアップロード
- [ ] **3** ターミナルで `firebase use --add` → `cd functions && npm install` → `firebase deploy --only functions,firestore:rules`（**未**: `.firebaserc` なし・`functions/node_modules` なし）
- [ ] **4** Xcode: Firebase の**製品**（FirebaseCore, FirebaseMessaging）を ChildGuard ターゲットに追加・Push Notifications の Capability 追加（**要確認**: パッケージは追加済みだが、ターゲットに FirebaseCore/FirebaseMessaging が未リンクの可能性）
- [ ] **5** 親＝シミュレータでアプリ起動 → 親モードで URL 入力 → 「親としてこの端末を登録」→ 「登録しました」を確認
- [ ] **6** 子＝実機で同じ URL を「親への通知用 URL」に保存 → 監視開始 → 制限がかかるまで使用 → 親側にプッシュが届くか確認

---

## 現在の状態（フォルダ確認結果）

| 項目 | 状態 |
|------|------|
| Firebase プロジェクト | ✅ 作成済み（childguard-72f89） |
| GoogleService-Info.plist | ✅ あり（ChildGuard/ChildGuard/ に配置） |
| Firebase SPM パッケージ | ✅ プロジェクトに追加済み（firebase-ios-sdk） |
| FirebaseCore / FirebaseMessaging をターゲットにリンク | ⚠️ 要確認（Xcode で ChildGuard ターゲット → General → Frameworks に FirebaseCore, FirebaseMessaging があるか確認） |
| Push Notifications（entitlements） | ❌ 未追加 |
| .firebaserc（Firebase プロジェクト紐づけ） | ❌ なし → 手順 3 の前に `firebase use --add` が必要 |
| functions/node_modules | ❌ なし → 手順 3 の前に `cd functions && npm install` が必要 |

**次にやるべきこと**: 下の **2**（APNs キー）か、**4**（Xcode で Firebase 製品リンク＋Push）のどちらかから。その後 **3**（デプロイ）→ **5〜6**（動作確認）。

---

## 1. Firebase プロジェクトの準備

1. [Firebase Console](https://console.firebase.google.com/) で **新規プロジェクト** を作成（または既存を使用）。
2. **Firestore Database** を有効化（テストモードで開始で可）。Cloud Functions が親の FCM トークンを保存するために使います。
3. **プロジェクトの設定** → **全般** → **マイアプリ** で **iOS アプリを追加**：
   - Apple のバンドル ID: `com.yoshi.ChildGuard`（実際の Bundle ID に合わせる）
   - **GoogleService-Info.plist** をダウンロードし、Xcode の ChildGuard ターゲットの **ChildGuard** グループにドラッグで追加（Copy items if needed にチェック）。

**注意**: **GoogleService-Info.plist は .gitignore に含まれており、Git にコミットしません。** API キーが GitHub などに公開されると Google から警告が届きます。リポジトリをクローンした人は、Firebase Console から自分用の plist をダウンロードして追加してください。

---

## 1.1. 「API キーが一般公開されています」と Google から届いた場合

GitHub などに **GoogleService-Info.plist** が含まれたままプッシュすると、Google が検知してメールで通知します。次の手順で対処してください。

1. **Google Cloud Console** でキーを無効化・再発行する  
   - プロジェクトの見つけ方：  
     - **[Firebase Console](https://console.firebase.google.com/)** にログイン → 一覧で **ChildGuard**（または作成したときの名前）をクリック。  
     - 左の **⚙ プロジェクトの設定** → **全般** の下の「プロジェクト ID」に **childguard-72f89** と出ていれば、その Firebase プロジェクトが GCP と連携しています。  
     - 同じページの **「Google Cloud で開く」**（または「プロジェクトを Google Cloud で管理」）をクリックすると、そのプロジェクトが開いた状態で GCP に移れます。  
     - または [Google Cloud Console](https://console.cloud.google.com/) に直接行く場合：画面上部の **プロジェクト名の横の▼** をクリック → 一覧に **ChildGuard** や **childguard-72f89** が出ていればそれを選択。出ない場合は、Firebase にログインしている **同じ Google アカウント** で GCP にログインしているか確認してください。  
   - プロジェクトを開いたら **API とサービス** → **認証情報** を開く。  
   - メールに記載の **API キー**（例: 末尾が …K57lK8I）をクリック。  
   - **キーを再生成** をクリックして新しいキーに取り替える（古いキーはすぐ無効になります）。

2. **Firebase から新しい GoogleService-Info.plist を取得する**  
   - [Firebase Console](https://console.firebase.google.com/) → プロジェクト **childguard-72f89** → **プロジェクトの設定**（歯車）→ **全般** → **マイアプリ**。  
   - 該当 iOS アプリの **GoogleService-Info.plist** を**再度ダウンロード**する（再生成後は新しいキーが含まれる場合があります。含まれない場合は、GCP の認証情報で該当キーの値をコピーし、plist 内の該当フィールドを手で書き換える必要がある場合があります）。  
   - ダウンロードした plist で、Xcode の **ChildGuard/ChildGuard/** にある既存の **GoogleService-Info.plist** を**上書き**する。

3. **今後 plist を Git に含めない**  
   - このリポジトリでは **GoogleService-Info.plist** を `.gitignore` に追加済みです。  
   - すでに Git で追跡している場合は、リポジトリからだけ外す（ファイルは手元に残す）ために次を実行してください。  
     ```bash
     git rm --cached ChildGuard/ChildGuard/GoogleService-Info.plist
     git commit -m "Stop tracking GoogleService-Info.plist (API key security)"
     ```  
   - その後は **この plist をコミット・プッシュしない**でください。別のマシンやクローンでは、Firebase Console から plist をダウンロードして追加します。

4. **（任意）API キーに制限をかける**  
   - GCP の **認証情報** で該当 API キーを編集し、**アプリの制限** で「iOS アプリ」を選び、Bundle ID に `com.yoshi.ChildGuard` を指定すると、このキーはそのアプリ以外では使えなくなります。

---

## 1.2. GitHub から「Secrets detected」「Action needed」と届いた場合

GitHub のシークレットスキャンで **Google API Key** などが検出され、メールで「Action needed: Secrets detected」と届くことがあります。**1.1 の手順に加えて**次を行ってください。

1. **リポジトリから plist の追跡を外し、プッシュする**（まだなら）  
   ```bash
   cd /Users/a0011414/CloudStation/VariousPrograms/ChildGuard   # リポジトリのルート
   git rm --cached ChildGuard/ChildGuard/GoogleService-Info.plist
   git commit -m "Stop tracking GoogleService-Info.plist (API key security)"
   git push
   ```  
   これで **最新のコミット** には GoogleService-Info.plist が含まれなくなります。

2. **Google 側でキーを再生成する**（1.1 の手順 1）  
   漏れたキーは **無効化・再発行** しないと、Git の過去履歴に残ったまま誰でも参照できます。必ず GCP の **認証情報** で **キーを再生成** してください。

3. **GitHub のアラートを「解消」する**  
   - GitHub の **a0011414/ChildGuard** リポジトリを開く。  
   - **Security** タブ → **Secret scanning**（または **Code security and analysis**）の **Alerts** を開く。  
   - 該当の「Google API Key」アラートを開き、**Resolve** や **Mark as resolved** を選ぶ。  
   - 「Revoke secret and resolve」など、**キーを無効化したうえで解消**するオプションがあれば、キー再生成後にそれを選ぶとよいです。

**注意**: `git rm --cached` と push をしても、**過去のコミット履歴には plist の内容が残ります**。そのため、**キーの再生成（無効化）は必ず行ってください**。履歴からも消したい場合は、`git filter-repo` などの履歴書き換えが必要になります（上級者向け）。

---

## 2. Cloud Messaging（FCM）の有効化

**目的**: FCM が iOS にプッシュを送れるように、Apple の APNs 用キー（.p8）を Firebase に登録する。

### A. Apple Developer で APNs キー（.p8）を用意する

1. [Apple Developer](https://developer.apple.com/account/) にログイン。
2. **Certificates, Identifiers & Profiles** を開く。
3. 左メニューで **Keys** をクリック。
4. **+**（新規キー）をクリック。
5. **Key Name** に任意の名前（例: ChildGuard APNs）を入力。
6. **Apple Push Notifications service (APNs)** にチェックを入れる。
7. **Continue** → **Register**。
8. 表示された画面で **Download** をクリックして **.p8 ファイル** をダウンロード。  
   **重要**: この .p8 は一度しかダウンロードできない。安全な場所に保存する。  
9. **Key ID** をメモする（Firebase に入力するため）。
10. 元の Keys 一覧で、作成したキーの **Configure** をクリックすると、そのキーに紐づく **App ID** を選べる。**ChildGuard の Bundle ID**（例: com.yoshi.ChildGuard）を選択して保存。

### B. Firebase に .p8 を登録する

1. [Firebase Console](https://console.firebase.google.com/) で、プロジェクト **childguard-72f89** を開く。
2. 左メニュー **Build** → **Cloud Messaging** をクリック。
3. 下にスクロールし、**Apple アプリ設定** セクションを開く。
4. 登録済みの iOS アプリ（ChildGuard）の行で **アップロード**（または鍵アイコン／設定）をクリック。
5. **APNs 認証キー** を選び、次を入力・選択する：
   - **APNs 認証キー (.p8 ファイル)**: A でダウンロードした .p8 をアップロード。
   - **キー ID**: A でメモした Key ID を入力。
   - **チーム ID**: Apple Developer の **Membership** に表示されている Team ID（例: F5558YDHK6）。
   - **Bundle ID**: アプリの Bundle ID（例: com.yoshi.ChildGuard）。
6. **アップロード**（または保存）をクリック。

これで FCM 経由で iOS にプッシュを送れるようになります。

---

## 3. Cloud Functions のデプロイ

**くわしい手順は下の「3-A. デプロイのやり方（詳しく）」を参照。** 流れだけ言うと：`firebase.json` があるフォルダへ移動 → `firebase use --add` でプロジェクト選択 → `cd functions && npm install` → `firebase deploy --only functions,firestore:rules`。

### 3-A. デプロイのやり方（詳しく）

**前提**: `firebase.json` があるフォルダで作業する。このプロジェクトでは **ChildGuard/ChildGuard**（ChildGuard フォルダの直下の ChildGuard）です。

---

**ステップ 1: ターミナルを開き、プロジェクトのフォルダに移動する**

- **ターミナル**（アプリケーション → ユーティリティ → ターミナル、または Spotlight で「ターミナル」）を開く。
- 次のコマンドで、`firebase.json` があるフォルダに移動する（パスは自分の環境に合わせて書き換える）：
  ```bash
  cd /Users/a0011414/CloudStation/VariousPrograms/ChildGuard/ChildGuard
  ```
- ここに `firebase.json` と `functions` フォルダがあることを確認する：
  ```bash
  ls -la firebase.json
  ls -la functions/package.json
  ```
  両方表示されれば OK。

---

**ステップ 2: Firebase CLI が入っているか確認し、未導入なら入れる**

- バージョン確認：
  ```bash
  firebase --version
  ```
  バージョンが表示されれば CLI は入っている。**command not found** のときは次へ。

- 未導入の場合、Node.js の **npm** でグローバルにインストールする：
  ```bash
  npm install -g firebase-tools
  ```
  パスを通すために `sudo` を求められたら、Mac のログインパスワードを入力する。  
  インストール後、もう一度 `firebase --version` で確認する。

---

**ステップ 3: Node.js のバージョンを確認する（20 以上が必要）**

- 確認：
  ```bash
  node -v
  ```
  `v20.x.x` や `v22.x.x` のように **20 以上**ならそのままでよい。  
  `v16` や `v18` のときは、デプロイでエラーになることがある。

- **20 以上にする方法**
  - [nodejs.org](https://nodejs.org/) から **LTS** をダウンロードしてインストールする。  
  - または **nvm**（Node Version Manager）を使っている場合：
    ```bash
    nvm install 20
    nvm use 20
    ```
  - その後、もう一度 `node -v` で 20 以上になっているか確認する。

---

**ステップ 4: Firebase にログインする**

- 次のコマンドを実行する：
  ```bash
  firebase login
  ```
- ブラウザが開き、**Google アカウント**でログインするよう求められる。Firebase プロジェクト（childguard-72f89）を作ったアカウントでログインする。
- ログインが終わるとターミナルに「Success! Logged in as ...」と出る。

---

**ステップ 5: このフォルダを、使う Firebase プロジェクトに紐づける**

- 初回だけ、または `.firebaserc` がまだ無いときに行う：
  ```bash
  firebase use --add
  ```
- 一覧から **childguard-72f89**（または自分の Firebase プロジェクト名）を **矢印キーで選び、Enter**。
- 「What do you want to use as your project alias?」と聞かれたら、そのまま **Enter**（デフォルトの `default` でよい）。
- 同じフォルダに **.firebaserc** というファイルができる。中身は `"default": "childguard-72f89"` のような形。

---

**ステップ 6: Functions の依存関係をインストールする**

- **functions** フォルダに移動する：
  ```bash
  cd functions
  ```
- npm で依存関係を入れる：
  ```bash
  npm install
  ```
  しばらく時間がかかることがある。終わると `functions` の中に **node_modules** フォルダができる。
- ひとつ上のフォルダに戻る：
  ```bash
  cd ..
  ```
  ここで `pwd` を実行すると、再び **ChildGuard/ChildGuard** になっているはず。

---

**ステップ 7: Cloud Functions と Firestore ルールをデプロイする**

- 次のコマンドを **firebase.json があるフォルダ**（いまの `ChildGuard/ChildGuard`）で実行する：
  ```bash
  firebase deploy --only functions,firestore:rules
  ```
- 初回は「Do you want to continue?」と聞かれることがある。**Y** を入力して Enter。
- デプロイが進むと、**Building...** → **Uploading...** のように表示される。完了すると最後に次のような表示が出る：
  ```
  ✔  Deploy complete!

  Function URL (registerParentToken): https://us-central1-childguard-72f89.cloudfunctions.net/registerParentToken
  Function URL (notifyParent): https://us-central1-childguard-72f89.cloudfunctions.net/notifyParent
  ```
- **Deploy complete!** が出れば成功。アプリでは **ベース URL**（`https://us-central1-childguard-72f89.cloudfunctions.net`）だけ使うので、末尾の関数名は付けない。

---

**エラーが出たときの確認**

| 出たメッセージ | 対処 |
|----------------|------|
| `Node.js version ... is not supported` | `node -v` で 20 以上にしてから再度 `firebase deploy`。 |
| `Permission denied` や `EACCES` | `npm install -g firebase-tools` を `sudo` 付きで試す。または Node を nvm で入れ直し、`npm install -g firebase-tools` を sudo なしで実行。 |
| `Project must be set` / `.firebaserc` がない | `firebase use --add` でプロジェクトを選び直す。 |
| `npm install` でエラー | `cd functions` のうえで `rm -rf node_modules package-lock.json` してから、もう一度 `npm install`。 |
| デプロイは成功したがアプリから 404 | 数分待ってから再試行。または Firebase Console → Build → Functions で **registerParentToken** / **notifyParent** が表示されているか確認。 |

---

**まとめ（コピペ用）**

`firebase.json` があるフォルダで、次を順に実行すればデプロイまで完了する：

```bash
cd /Users/a0011414/CloudStation/VariousPrograms/ChildGuard/ChildGuard
firebase use --add
# → 一覧で childguard-72f89 を選択
cd functions
npm install
cd ..
firebase deploy --only functions,firestore:rules
```

（すでに `firebase use` 済みで `.firebaserc` がある場合は、`firebase use --add` は省略してよい。）

---

## 4. Xcode 側の設定

1. **Firebase を SPM で追加**  
   **File** → **Add Package Dependencies** → URL に  
   `https://github.com/firebase/firebase-ios-sdk` を入力。  
   **FirebaseCore** と **FirebaseMessaging** を ChildGuard ターゲットに追加。

2. **Push Notifications の Capability**  
   - Xcode でプロジェクトを開く。  
   - 左の **プロジェクトナビゲータ** で、一番上の **青いプロジェクトアイコン**（ChildGuard）をクリック。  
   - 中央の **TARGETS** 一覧で **ChildGuard**（メインアプリ。Extension ではない）を選択。  
   - 上端のタブで **Signing & Capabilities** をクリック。  
   - **+ Capability** ボタンをクリック。  
   - 一覧から **Push Notifications** を探してダブルクリック（または選択して Enter）。  
   - 「Push Notifications」が Capability 一覧に追加されれば完了。

3. **バックグラウンドモード（任意）**  
   リモート通知を受け取るだけなら必須ではないが、**Background Modes** で **Remote notifications** にチェックを入れておいてもよい。

4. **GoogleService-Info.plist** が ChildGuard ターゲットの **Copy Bundle Resources** に含まれていることを確認。

---

## Cloud Functions の URL とは？（どこに何を入れるか）

**短く言うと**: アプリの「Cloud Functions の URL」欄には、**次の 1 行をそのままコピペ**して使います。

```
https://us-central1-childguard-72f89.cloudfunctions.net
```

- **これだけ**で OK です。末尾に `/registerParentToken` や関数名は付けません。
- このプロジェクト（childguard-72f89）では、リージョンが `us-central1` なら上記の形になります。デプロイに成功していれば、この URL で動きます。

**デプロイがまだ成功していない場合**（Node のバージョンエラーで止まったなど）は、先に「Node を 20 以上にしてからもう一度 deploy」が必要です。成功するとターミナルに `✔  Deploy complete!` と、各関数の URL が表示されます。そのとき表示されるアドレスの「`https://...cloudfunctions.net`」の部分が、上と同じ形になっているはずです。

**Firebase Console で確認する場合**: [Firebase Console](https://console.firebase.google.com/) → プロジェクト **childguard-72f89** → **Build** → **Functions**。一覧に **registerParentToken** と **notifyParent** が出ていればデプロイ済みで、それぞれの「トリガー」や URL の共通部分が上記のベース URL です。

---

## 5. 動作確認（子＝実機・親＝シミュレータ）

### 使う URL

上で確認した **ベース URL** をメモしておく。  
例: `https://us-central1-childguard-72f89.cloudfunctions.net`  
（あなたのプロジェクトでは `childguard-72f89` の部分が同じならこの形です。）

---

### ステップ 1：親役（シミュレータ）で「親」を登録する

1. **シミュレータ**で ChildGuard を起動する。
2. 画面上部の **親** を選択して **親モード** にする。
3. 下にスクロールし、**「親への通知（FCM）」** の欄を探す。
4. **「Cloud Functions の URL」** の入力欄に、ベース URL を**そのまま**貼り付ける。  
   例: `https://us-central1-childguard-72f89.cloudfunctions.net`
5. **「親としてこの端末を登録」** をタップする。
6. **「登録しました。子の端末で制限がかかるとこの端末に通知が届きます。」** と出れば OK。  
   出ない場合は、URL の typo や前後のスペース、末尾の `/` の有無を確認する。

---

### ステップ 2：子役（自分の iPhone）で制限をかける

1. **自分の iPhone** で ChildGuard を起動する。
2. 画面上部の **子** を選択して **子モード** にする。
3. 必要なら「保護者による管理を許可」→ 制限するアプリを選んで **「この選択を保存」** まで行う。
4. 下にスクロールし、**「親への通知用 URL（任意）」** の入力欄に、**ステップ 1 で使ったのと同じベース URL** を入力する。  
   例: `https://us-central1-childguard-72f89.cloudfunctions.net`
5. **「保存」** をタップする。
6. **「監視を開始」** をタップする。
7. **制限対象にしたアプリ** を、設定した分数（例: 1 分や 2 分）だけ実際に使う。  
   （監視を開始した**あと**から使った時間だけカウントされます。）

---

### ステップ 3：結果の確認

- **子の iPhone**: 「制限時間を超えました」の通知が出て、そのアプリを開き直すとシールドがかかる。
- **親のシミュレータ**: しばらくすると **「ChildGuard / 制限がかかりました」** のプッシュが届く場合があります。  
  （シミュレータでは届かないこともあるので、そのときは親役を **実機の iPhone** にして、同じ手順で「親としてこの端末を登録」からやり直すと確実です。）

---

## 「FCM トークンを取得できません」と出るとき

**親としてこの端末を登録** でこのメッセージが出る場合、**アプリが表示しているメッセージ**を確認する。

- **「GoogleService-Info.plist がアプリに含まれていません」** と出た場合  
  → 下の **3. GoogleService-Info.plist** の手順で、**Copy Bundle Resources** に plist を追加する。

- **「FCM トークンを取得できません。実機で…」** と出た場合  
  → plist は含まれている。下の 1・2・5・6 を確認する（実機・Push Capability・通知許可・再インストール）。

次の順に確認する。

1. **実機で試しているか**  
   シミュレータでは FCM トークンが取得できません。**必ず実機の iPhone** でアプリを起動し、「親としてこの端末を登録」をタップしてください。

2. **Push Notifications の Capability**  
   Xcode → プロジェクト → **TARGETS** → **ChildGuard**（メインアプリ）→ **Signing & Capabilities**。  
   **Push Notifications** が一覧に無ければ **+ Capability** から **Push Notifications** を追加する。  
   ※ Debug 用の **ChildGuard.entitlements** にも `aps-environment`（development）が入っているか確認する。入っていないと実機の Debug ビルドで FCM トークンが取得できません。

3. **GoogleService-Info.plist をバンドルに含める**  
   - プロジェクト内に **GoogleService-Info.plist** があるか確認する（ChildGuard/ChildGuard/ フォルダ内）。  
   - **TARGETS** → **ChildGuard** → **Build Phases** → **Copy Bundle Resources** に **GoogleService-Info.plist** が含まれているか確認する。  
   - **無ければ** **+** をクリック → **GoogleService-Info.plist** を選んで追加する。  
   - プロジェクトで「フォルダを同期」している場合、plist が自動で Copy に入らないことがあるため、上記で明示的に追加する。

4. **Firebase のリンク**  
   **TARGETS** → **ChildGuard** → **General** → **Frameworks, Libraries, and Embedded Content** に **FirebaseCore** と **FirebaseMessaging** が入っているか確認する。無ければ **+** で追加する（SPM で firebase-ios-sdk を追加済みなら、その中から選べる）。

5. **通知の許可**  
   iPhone の **設定** → **ChildGuard** → **通知** で、通知が **許可** になっているか確認する。  
   まだ許可していない場合は、一度アプリ側で通知を許可するダイアログを出し、「許可」を選んでから再度「親としてこの端末を登録」を試す。

6. **アプリの再インストール**  
   上記を直したあとも取れない場合は、実機からアプリを**完全に削除**し、Xcode からもう一度インストールする。起動時に「通知を許可しますか？」が出たら**許可**を選び、その後で「親としてこの端末を登録」を試す。

7. **通知許可のタイミング**  
   アプリは起動時に通知許可を一度だけ求め、許可後にリモート通知登録を行う。いったん「許可しない」にした場合は、**設定 → ChildGuard → 通知** でオンにしたうえで、アプリを**終了してから再起動**し、もう一度「親としてこの端末を登録」をタップする（FCM トークンは再起動後に取得される）。

※ 実機＋Push Capability＋通知許可 がそろっていれば、登録時に FCM トークンが取得できるようになります。トークンがまだ準備できていない場合は、約2.5秒後に自動で再試行します。

---

## 注意

- **親** で「親としてこの端末を登録」すると FCM トークンがサーバーに保存されます。**子の端末** では **家族コード（8桁）** を入力するか QR で読み取り、保存しておく必要があります（子の Extension がこのコードで `notifyParent` を呼びます）。
- シミュレータでは FCM トークンは取れません。親の登録は **実機** で行ってください。
