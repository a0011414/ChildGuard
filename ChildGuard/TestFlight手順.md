# TestFlight で ChildGuard を配布する手順

一つずつ進めてください。前のステップが終わってから次へ。

---

## TestFlight にアプリが出るまで（全体の流れ）

**「TestFlight にアプリが出る」＝ iPhone の TestFlight アプリの一覧に ChildGuard が表示され、インストールできる状態になることです。** そのためにやることは次のとおりです。

| 順番 | やること | どこで |
|------|----------|--------|
| 1 | App Store Connect に ChildGuard アプリがあるか確認（なければ新規作成） | ブラウザ：appstoreconnect.apple.com |
| 2 | Xcode で **Archive** を作る | Mac：Xcode |
| 3 | そのアーカイブを **Distribute App** で App Store Connect に **アップロード** | Mac：Xcode Organizer |
| 4 | App Store Connect 側でビルドが「処理」されるのを待つ（5〜30 分程度） | ブラウザ：TestFlight タブ |
| 5 | **テスト担当者**（自分や家族のメールアドレス）を **内部テスト** に追加する | ブラウザ：TestFlight タブ |

ここまで終わると、追加した人の **iPhone の TestFlight アプリ** に ChildGuard が表示され、**インストール** ボタンで入れられるようになります。招待メールが届くので、そのリンクからでも入れられます。

くわしい操作は、下の **ステップ 0** から順に読んでください。

---

## 用語の説明（TestFlight って何？ テスト担当者って誰？）

- **TestFlight（テストフライト）**  
  Apple が用意している「**リリース前のアプリを配布して試してもらう**」仕組みです。  
  - **TestFlight アプリ**: iPhone に **App Store から「TestFlight」で検索してインストール**する、Apple 公式のアプリです。  
  - 開発者がアップロードしたビルドが、この TestFlight 経由でテスト担当者の iPhone に配布されます。  
  - サイトだけではなく、**iPhone では TestFlight アプリ**を使って ChildGuard をインストールします。

- **テスト担当者**  
  **あなたが「この人に試してもらう」と指定した人**です。Apple の審査員や Apple の社員ではありません。  
  - **一人で開発している場合**: テスト担当者 = **あなた自身**です。あなたの Apple ID（メールアドレス）を「内部テスト」の担当者として追加すると、あなたの iPhone で TestFlight から ChildGuard をインストールして試せます。  
  - 家族や友人に試してもらう場合は、その人たちのメールアドレスを「外部テスト」などで追加します。

- **流れのイメージ**  
  1. あなたが Xcode でアーカイブ → App Store Connect にアップロード  
  2. App Store Connect の TestFlight で「テスト担当者」にあなた（や家族）のメールアドレスを追加  
  3. テスト担当者の iPhone に **招待メール** が届く  
  4. その iPhone で **TestFlight アプリ** を開く（まだなら App Store からインストール）  
  5. 招待に従って **ChildGuard** を TestFlight からインストール → 実機で試す  

- **Developer モードは？**  
  **TestFlight からインストールする場合は不要**です。Developer モードは、Xcode から実機に直接 Run するときなどに必要になります。TestFlight のビルドは配布用の署名なので、通常のアプリと同様にインストールできます。  

---

## ステップ 0：前提の確認

- Apple Developer Program に加入済みであること
- Family Controls の承認済みであること（済み）
- Mac に Xcode で ChildGuard がビルドできる状態であること

---

## ステップ 1：App Store Connect にアプリがあるか確認する

1. ブラウザで **https://appstoreconnect.apple.com** を開く
2. Apple Developer の Apple ID でログインする
3. **マイアプリ** をクリックする
4. 一覧に **ChildGuard** があるか確認する

### 1-A. ChildGuard が**ある**場合

→ **ステップ 2** へ進む。

### 1-B. ChildGuard が**ない**場合

1. **+** → **新規アプリ** をクリックする
2. **プラットフォーム**: iOS にチェック
3. **名前**: ChildGuard
4. **主言語**: 日本語（またはお好みで）
5. **バンドル ID**: ドロップダウンから **com.yoshi.ChildGuard** を選ぶ  
   （一覧にない場合は、先に [developer.apple.com/account](https://developer.apple.com/account) → Certificates, Identifiers & Profiles → Identifiers で App ID を登録する）
6. **SKU**: 任意の英数字（例: `childguard001`）
7. **ユーザーアクセス**: フルアクセス（通常はこれ）
8. **作成** をクリックする

→ 作成できたら **ステップ 2** へ。

---

## ステップ 2：Xcode でアーカイブ（Archive）を作る

1. **Xcode** で ChildGuard プロジェクトを開く
2. ツールバーの実行先（デバイス選択）をクリックする
3. **Any iOS Device (arm64)** を選ぶ  
   （実機を接続している場合は、その実機を選んでもよい。Archive は **Any iOS Device** で行うのが一般的）
4. メニュー **Product** → **Archive** を選ぶ
5. ビルドが終わるまで待つ（数分かかることがある）
6. 完了すると **Organizer** ウィンドウが開き、最新のアーカイブが表示される

### Archive がグレーアウトしている場合

- 実行先が **シミュレータ** のままになっていると Archive できません。**Any iOS Device** に切り替えてから再度 **Product → Archive** を実行する。

---

## ステップ 3：アーカイブを App Store Connect にアップロードする

1. Organizer で、今つくった **ChildGuard** のアーカイブを選択した状態にする
2. 右側の **Distribute App** ボタンをクリックする
3. **App Store Connect** → **Next**
4. **Upload** → **Next**
5. オプションはそのまま（デフォルト）→ **Next**
6. 署名は **Automatically manage signing** のまま → **Next**
7. **Upload** をクリックする
8. アップロードが終わるまで待つ
9. **Done** をクリックする

---

## ステップ 4：App Store Connect でビルドを処理させる

1. ブラウザで **App Store Connect** → **マイアプリ** → **ChildGuard** を開く
2. 左メニューで **TestFlight** タブをクリックする
3. **iOS** の下に、いまアップロードしたビルドが表示されるまで待つ（**5〜30 分**かかることがある）
4. ビルドの横に「処理中」→「有効」のような状態になる

### ビルドが「欠落したコンプライアンス」などで黄色い場合

- そのビルドをクリックし、**輸出コンプライアンス**（暗号化の使用）を答える。  
  ChildGuard は標準の HTTPS などだけなら「いいえ」でよいことが多い。保存する。

---

## ステップ 5：テスト担当者を追加する（自分で試す場合）

1. TestFlight 画面の **内部テスト** のところで **+** または **テスト担当者を追加** をクリックする
2. **App Store Connect のユーザー**（同じチームのメンバー）を追加する場合は、そのメールアドレスを選ぶ  
   自分だけ試す場合は、ログインしている Apple ID がすでにチームにいれば、そのメールアドレスを追加する
3. 追加した担当者に **TestFlight の招待メール** が届く
4. **iPhone** で、そのメールの「View in TestFlight」などのリンクをタップする  
   または App Store から **TestFlight** アプリをインストールし、招待メールに書いてある手順で ChildGuard をインストールする

### 外部テスト（家族など App Store Connect にいない人）の場合

- **外部テスト** のグループを作り、テスト担当者のメールアドレスを追加する
- 初回は **Beta アプリの審査** が入り、承認まで最大 24〜48 時間かかることがある

---

## ステップ 6：iPhone で TestFlight からインストールする

**（すでにテスト担当者に追加されていて、ビルドが TestFlight に「有効」になっている場合）**

### iPhone でやること（もう一度インストールする場合も同じ）

1. **TestFlight アプリ** を開く。  
   まだ入っていなければ、**App Store** で「TestFlight」と検索して **TestFlight**（Apple 公式）をインストールする。
2. 一覧に **ChildGuard** が出ていることを確認する。  
   （招待メールの「TestFlight で表示」などのリンクをタップしてもここに来る）
3. **ChildGuard** をタップする。
4. **「インストール」** または **「更新」** をタップする。
5. インストールが終わったら、ホーム画面の **ChildGuard** アイコンから起動して試す。

**招待メールが届いている場合**  
メール本文の **「View in TestFlight」** や **「TestFlight で表示」** のリンクをタップすると、TestFlight アプリが開き、ChildGuard の画面になる。あとはそこから **インストール** をタップする。

---

## 親子で試すとき（2 台の iPhone で TestFlight から入れる場合）

**想定**: 親用の iPhone と子用の iPhone の 2 台で、制限と「親への通知」まで試したい場合。

### 準備

1. **TestFlight のテスト担当者**に、**親と子の両方の Apple ID（メールアドレス）** を追加する。  
   - 内部テストなら App Store Connect のユーザーを追加。  
   - 家族などは**外部テスト**で追加し、招待メールで TestFlight から ChildGuard をインストールしてもらう。
2. **親の iPhone** と **子の iPhone** のそれぞれで、TestFlight から **ChildGuard をインストール**する。
3. **Cloud Functions の URL** を用意する（デプロイ済みなら `https://us-central1-childguard-72f89.cloudfunctions.net`）。  
   親の iPhone で「URL を QR で表示」→ 子の iPhone で「QRで読み取る」で渡してもよい。

### 親の iPhone でやること

1. ChildGuard を起動し、**親** モードにする。
2. 「1日の利用時間の上限」を入力して **保存**。
3. 「親への通知（FCM）」の **Cloud Functions の URL** を入力（または QRで読み取る）。
4. **「親としてこの端末を登録」** をタップし、「登録しました」と出ることを確認。

### 子の iPhone でやること

1. ChildGuard を起動し、**子** モードにする。
2. 「保護者による管理を許可する」→ 認可する。
3. 「制限するアプリ・Web」でアプリを選び **「この選択を保存」**。
4. 「親への通知用 URL」に、親で使ったのと**同じ URL** を入力（または QRで読み取る）→ **保存**。
5. **「監視を開始」** をタップする。
6. 制限したアプリを、設定した分数だけ使う。

### 確認

- 子の iPhone に「制限時間を超えました」の通知 → シールドがかかる。
- 親の iPhone に「制限がかかりました」の FCM プッシュが届く。

※ 親子とも **同じ TestFlight ビルド** を入れれば、上記の流れで試せます。片方だけ Xcode から直接 Run したビルドでも動きますが、URL や設定は同じにしてください。

---

## よくあるつまずき

| 現象 | 対処 |
|------|------|
| **Build input file cannot be found: ... .mobileprovision** | 古いプロビジョニングプロファイルを参照している。**対処**: (1) Xcode を終了する。(2) Finder で **移動 → フォルダへ移動** に `~/Library/Developer/Xcode/UserData/Provisioning Profiles` と入力して開く。(3) 中身の `.mobileprovision` をゴミ箱に移す（全部でよい）。(4) Xcode を起動し、各ターゲットの **Signing & Capabilities** で **Automatically manage signing** がオンで、**Provisioning Profile** が「自動」になっているか確認する。(5) **Product → Clean Build Folder** のあと、再度ビルドする。 |
| **Your team has no devices** | iPhone を USB で接続し、実行先をその iPhone にして一度 Run（⌘R）する。デバイスがチームに登録されたら、実行先を **Any iOS Device** に戻して Archive。 |
| Archive がグレー | 実行先を **Any iOS Device** にする |
| アップロード後「処理中」のまま | 最大 30 分ほど待つ。それ以上なら App Store Connect の「ビルド」一覧でエラーがないか確認 |
| TestFlight にビルドが出ない | 同じバージョン・ビルド番号が App Store Connect の「ビルド」に表示されているか確認。表示されていれば TestFlight タブで選べる |
| 実機で「信頼」が出る | 設定 → 一般 → VPN とデバイス管理 で開発元を信頼する（Xcode から直接 Run したときと同じ） |

---

## 参照

- [TestFlight の使い方（Apple）](https://developer.apple.com/testflight/)
- 申請メモ: App Store Connect でのアプリ追加は「申請メモ.md」の App Apple ID の節も参照
