# ChildGuard — 引き継ぎメモ

このフォルダ（**VariousPrograms/ChildGuard**）では **ChildGuard** アプリの開発を進める。  
**SelfGuard**（セルフコントロール）は **VariousPrograms/SelfGuard**、その他アプリはそれぞれのフォルダを参照。  
法人まわり・LC-X研究会の前提は **`LC-X研究会_引き継ぎメモ.md`** を参照。

---

## 1. ChildGuard とは

- **役割**: 親子で決めたルールに従い、利用時間の制限や親への通知を行うペアレンタルコントロールアプリ。
- **利用者**: 親（ルール設定・通知受け取り）と子（制限を受ける側）。1本のアプリで親モード／子モードを切り替える。
- **プロトタイプの核**: 「1日〇分まで」に達したら親に通知し、自動で使用制限（FCM ＋ Device Activity / シールド）。

---

## 2. フォルダ構成（いま入っているもの）

| パス | 説明 |
|------|------|
| **ChildGuard/ChildGuard.xcodeproj** | Xcode プロジェクト。本体アプリ ＋ ChildGuardDeviceActivityMonitorExtension。 |
| **ChildGuard/ChildGuard/** | 本体アプリ（SwiftUI）。親/子モード、FamilyActivityPicker、DeviceActivityMonitoring、FCM 登録・家族コード・QR など。 |
| **ChildGuard/ChildGuardDeviceActivityMonitorExtension/** | Device Activity 拡張。しきい値到達時にシールド＋親へ FCM 通知。 |
| **ChildGuard/functions/** | Firebase Cloud Functions（registerParentToken, notifyParent）。FCM 用。 |
| **要件メモ.md** | 誰が・何を・どのルールで。ルールの例・家族ID・共有の流れ。 |
| **技術メモ.md** | iOS / Family Controls / CloudKit・FCM 方針、制限の仕様メモ。 |
| **申請メモ.md** | Family Controls 申請の手順・識別情報・申請文下書き。 |
| **ChildGuard/TestFlight手順.md** | TestFlight 配布の手順。 |
| **ChildGuard/FCM親への通知 設定手順.md** | FCM・Firebase の設定手順。 |

---

## 3. 技術メモ（要点）

- **App Group**: `group.com.yoshi.ChildGuard`。家族コード・FCM URL・選択は App Group の UserDefaults で共有。
- **Family Controls 申請**: 配布前に Apple へ申請必須。`申請メモ.md` 参照。
- **実機必須**: Device Activity / シールドはシミュレータでは動かない。
- **ルール保存**: UserDefaults ＋ CloudKit（親→子共有は CKShare 想定）。詳細は `技術メモ.md`。

---

## 4. 親子の連携（2本柱）と現状

**親子の連携**は次の2つを指す。

|  pillar | 内容 | 現状メモ |
|--------|------|----------|
| **① ルールの共有（親→子）** | 親の端末で設定した「1日〇分」などのルールを、子の端末に届ける。技術的には CloudKit の CKShare（親が「子どもと共有」で URL 発行 → 子がその URL を開いて共有承諾）。 | **対応済み**（Rule.swift で shared を取得。実機で要確認）。 |
| **② 親への通知（制限到達時）** | 子の端末で制限がかかったときに、親の端末にプッシュ通知が届く。家族ID（8桁）を親が発行 → 子がコード入力 or QR で保存 → Extension が notifyParent 呼び出し → FCM で親に送信。 | まだできていない。 |

- **制限そのもの**は、**子の iPhone 上で親モードにして時間を指定し、子モードで制限開始**すれば **効いている**。
- **親の iPhone の親モードから何をしても、子の iPhone には届いていない**。① ルール共有が動いていないため。

### ① ルール共有が届かない原因の整理

- 親の iPhone で「子どもと共有」をタップすると、**CKShare の URL**（iCloud の共有リンク）が発行され、ShareLink で送れる。
- 子がそのリンクをタップすると、多くの場合 **Safari（iCloud の Web）で開く**。子がそこで「承諾」すると、共有は**子の iCloud には追加される**が、**アプリには URL が渡らない**。
- アプリの `onOpenURL` → `acceptShare(metadata)` が呼ばれるのは、**アプリがその URL で起動した場合**だけ。Safari で承諾しただけではアプリは起動しないため、`acceptShare` は呼ばれない。
- さらに、子側の **RuleStore** は起動時に **privateCloudDatabase** からしか読んでいない（`fetchFromCloudKit()`）。**sharedCloudDatabase**（他者から共有されたゾーン）を参照していないため、Safari で共有を承諾していても、アプリはその共有ルールを読みにいかない。

**修正の方向性**: 子側の RuleStore で、**sharedCloudDatabase から共有されているルールを取得する**処理を追加する。起動時や画面表示時に「共有ゾーンにルールがあればそれを採用し、なければ従来どおり private / UserDefaults」とする。これで、親が共有したあと子が Safari で承諾していれば、子のアプリを開いたときに親のルールが反映される。

**→ 対応済み（Rule.swift）**: `fetchFromSharedCloudKit` を追加。起動時にまず shared を問い合わせ、1件でもあればそのルールを採用し、なければ従来どおり private を読む。親の iPhone で「子どもと共有」→ 子が Safari でリンクを開いて承諾（または共有リンクの **QR を子が読み取る**）→ 子の iPhone でアプリを起動すると、親が設定した「1日〇分」が表示される想定。

**共有リンクのQR と 家族コード（ID）の役割**: 共有リンクのQRは**ルールを子の端末に届ける**用。家族コード（8桁）は**制限がかかったときに、どの親の端末に FCM で通知するか**を識別する用。CloudKit の共有は「誰に通知するか」の情報を持たないため、通知先を決めるために家族コードは別途必要。両方使う。

**「共有リンクを用意できませんでした」と出る場合**: ルール共有は **CloudKit** を使うため、アプリに **iCloud（CloudKit）の Capability** が必要。  
- **手順の場所**: ** [CloudKit設定手順.md](CloudKit設定手順.md) ** に「どこで何を選ぶか」をまとめた。  
- 要点: Xcode で **ターゲット ChildGuard → Signing & Capabilities → + Capability → iCloud** を追加 → **CloudKit** にチェック → **Containers** の **+** で **iCloud.com.yoshi.ChildGuard** を選択または新規作成。  
- 実機で iCloud にサインインしていること（バックアップのオン/オフは不要）。  
- 失敗時は **エラー文がそのまま表示**されるので、表示内容で原因を切り分け可能。

---

## 5. このフォルダでやること（続き・次のステップ）

1. **親子の連携を動かす**  
   - ① ルール共有: CKShare の「子どもと共有」→ 子が URL で受け取り承諾 → 子のアプリにルールが反映する流れの確認・修正。  
   - ② 親への通知: 親で「親として登録」→ 家族コードを子が入力（or QR）→ 制限到達時に親に FCM が届く流れの確認・修正。Firebase / FCM 設定は `ChildGuard/FCM親への通知 設定手順.md` 参照。
2. **開発・仕様の詰め**: 要件メモ・技術メモに沿った実装・調整。
3. **Family Controls 申請**: 未申請なら `申請メモ.md` の手順で申請。
4. **実機で動作確認**: 親モードでルール・家族コード・FCM 登録 → 子モードで監視開始 → 制限・親への通知を確認。
5. **TestFlight**: `ChildGuard/TestFlight手順.md` に従い、家庭で配布。法人化後は組織アカウントへ移管の想定（LC-X 引き継ぎメモ参照）。

---

## 6. 参照

- 全体のアプリ開発・法人の流れ: **`LC-X研究会_引き継ぎメモ.md`**
- セルフコントロール版: **VariousPrograms/SelfGuard** の `引き継ぎメモ.md`
- 本メモは、ChildGuard アプリの作業時の「文脈の引き継ぎ」用。
