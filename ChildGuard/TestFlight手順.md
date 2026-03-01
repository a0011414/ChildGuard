# TestFlight で ChildGuard を配布する手順

一つずつ進めてください。前のステップが終わってから次へ。

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

1. テスト担当者の **iPhone** で、招待メールのリンクを開く、または **TestFlight** アプリを開く
2. **ChildGuard** が表示されたら **インストール** をタップする
3. インストール後、通常のアプリのようにホーム画面から起動して試す

---

## よくあるつまずき

| 現象 | 対処 |
|------|------|
| Archive がグレー | 実行先を **Any iOS Device** にする |
| アップロード後「処理中」のまま | 最大 30 分ほど待つ。それ以上なら App Store Connect の「ビルド」一覧でエラーがないか確認 |
| TestFlight にビルドが出ない | 同じバージョン・ビルド番号が App Store Connect の「ビルド」に表示されているか確認。表示されていれば TestFlight タブで選べる |
| 実機で「信頼」が出る | 設定 → 一般 → VPN とデバイス管理 で開発元を信頼する（Xcode から直接 Run したときと同じ） |

---

## 参照

- [TestFlight の使い方（Apple）](https://developer.apple.com/testflight/)
- 申請メモ: App Store Connect でのアプリ追加は「申請メモ.md」の App Apple ID の節も参照
