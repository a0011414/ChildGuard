//
//  Rule.swift
//  ChildGuard
//
//  最小のルールモデル：「1日〇分まで」。UserDefaults ＋ CloudKit で保存。
//

import Foundation
import Combine
import CloudKit

/// プロトタイプで使う1本のルール。「1日の利用時間の上限（分）」だけを持つ。
struct Rule: Codable, Equatable {
    /// 1日の利用時間の上限（分）。0 は「未設定」とする。
    var dailyLimitMinutes: Int
}

// MARK: - 保存・読み込み（UserDefaults ＋ CloudKit）

private let key = "childguard_rule"

private enum CloudKitConfig {
    /// 共有はカスタムゾーンでのみ対応。既定ゾーンでは CKShare が使えない。
    static let zoneName = "ChildGuardRules"
    static let recordType = "Rule"
    static let recordName = "currentRule"
    static let keyMinutes = "dailyLimitMinutes"
    /// entitlements の iCloud コンテナ ID と一致させる
    static let containerIdentifier = "iCloud.com.yoshi.ChildGuard"
    static var customZoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    }
}

/// Preview 実行中かどうか（CloudKit をスキップしてクラッシュを防ぐ）
private var isRunningInPreview: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}

final class RuleStore: ObservableObject {
    @Published var rule: Rule {
        didSet { save() }
    }

    /// entitlements で指定したコンテナを明示的に使用。Preview 時は nil。
    private lazy var container: CKContainer? = {
        guard !isRunningInPreview else { return nil }
        return CKContainer(identifier: CloudKitConfig.containerIdentifier)
    }()

    init() {
        self.rule = RuleStore.loadFromUserDefaults()
        if !isRunningInPreview {
            fetchFromSharedCloudKit { [weak self] didFindShared in
                guard let self = self else { return }
                if !didFindShared {
                    self.fetchFromCloudKit()
                }
            }
        }
    }

    private func save() {
        saveToUserDefaults()
        if !isRunningInPreview {
            saveToCloudKit()
        }
    }

    // MARK: - UserDefaults（ローカル即時反映）

    private static func loadFromUserDefaults() -> Rule {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(Rule.self, from: data) else {
            return Rule(dailyLimitMinutes: 0)
        }
        return decoded
    }

    private func saveToUserDefaults() {
        guard let data = try? JSONEncoder().encode(rule) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    // MARK: - CloudKit（同期・のちに共有の土台）

    private func fetchFromCloudKit() {
        guard let container = container else { return }
        let db = container.privateCloudDatabase
        ensureZoneExists(in: db) { [weak self] zoneID in
            guard let self = self, let zoneID = zoneID else { return }
            let recordID = CKRecord.ID(recordName: CloudKitConfig.recordName, zoneID: zoneID)
            db.fetch(withRecordID: recordID) { [weak self] record, error in
                guard let self = self, let record = record,
                      let minutes = record[CloudKitConfig.keyMinutes] as? Int else { return }
                DispatchQueue.main.async {
                    self.rule = Rule(dailyLimitMinutes: minutes)
                    self.saveToUserDefaults()
                }
            }
        }
    }

    private func saveToCloudKit() {
        guard let container = container else { return }
        let db = container.privateCloudDatabase
        ensureZoneExists(in: db) { [weak self] zoneID in
            guard let self = self, let zoneID = zoneID else { return }
            let recordID = CKRecord.ID(recordName: CloudKitConfig.recordName, zoneID: zoneID)
            let record = CKRecord(recordType: CloudKitConfig.recordType, recordID: recordID)
            record[CloudKitConfig.keyMinutes] = self.rule.dailyLimitMinutes
            db.save(record) { _, _ in }
        }
    }

    /// 共有可能なカスタムゾーンを作成する。既に存在する場合はエラーになるが、その場合も zoneID を返して後続の fetch/save に進む。
    private func ensureZoneExists(in db: CKDatabase, completion: @escaping (CKRecordZone.ID?) -> Void) {
        let zoneID = CloudKitConfig.customZoneID
        let zone = CKRecordZone(zoneID: zoneID)
        db.save(zone) { _, error in
            // 成功 or 既存ゾーンで競合 → いずれも zoneID を返す
            DispatchQueue.main.async { completion(zoneID) }
        }
    }

    // MARK: - 共有 DB からルールを読む（親が共有し子が Safari 等で承諾した場合）

    /// 他者から共有されたゾーンにルールがあればそれを採用する。親の iPhone で共有→子が Safari で承諾したあと、子のアプリを開くとここで取得できる。共有がなければ completion(false) で private を読む。
    private func fetchFromSharedCloudKit(completion: @escaping (Bool) -> Void) {
        guard let container = container else {
            DispatchQueue.main.async { completion(false) }
            return
        }
        let db = container.sharedCloudDatabase
        let query = CKQuery(recordType: CloudKitConfig.recordType, predicate: NSPredicate(value: true))
        let op = CKQueryOperation(query: query)
        op.qualityOfService = .userInitiated
        var didFindShared = false
        op.recordMatchedBlock = { [weak self] _ /* recordID */, result in
            guard case .success(let record) = result,
                  let self = self,
                  let minutes = record[CloudKitConfig.keyMinutes] as? Int else { return }
            didFindShared = true
            DispatchQueue.main.async {
                self.rule = Rule(dailyLimitMinutes: minutes)
                self.saveToUserDefaults()
            }
        }
        op.queryResultBlock = { _ in
            DispatchQueue.main.async {
                completion(didFindShared)
            }
        }
        db.add(op)
    }

    // MARK: - 親→子共有（CKShare）

    /// ルールを子どもと共有するための URL を用意する。カスタムゾーンでレコードを用意してから CKShare を作成する。
    func prepareShareURL(completion: @escaping (URL?, _ errorMessage: String?) -> Void) {
        if isRunningInPreview {
            DispatchQueue.main.async { completion(nil, nil) }
            return
        }
        guard let container = container else {
            DispatchQueue.main.async { completion(nil, "iCloud が利用できません。設定で iCloud にサインインし、このアプリで iCloud が有効か確認してください。") }
            return
        }
        let db = container.privateCloudDatabase
        ensureZoneExists(in: db) { [weak self] zoneID in
            guard let self = self, let zoneID = zoneID else {
                DispatchQueue.main.async { completion(nil, "共有用のゾーンを準備できませんでした。") }
                return
            }
            let recordID = CKRecord.ID(recordName: CloudKitConfig.recordName, zoneID: zoneID)
            self.fetchRecordAndCreateShare(db: db, recordID: recordID, zoneID: zoneID, retryCount: 0, completion: completion)
        }
    }

    /// レコード取得→共有作成。エラー15（サーバー拒否）のときは1回だけリトライする。
    private func fetchRecordAndCreateShare(db: CKDatabase, recordID: CKRecord.ID, zoneID: CKRecordZone.ID, retryCount: Int, completion: @escaping (URL?, String?) -> Void) {
        db.fetch(withRecordID: recordID) { [weak self] record, error in
            guard let self = self else { return }
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                // レコードが存在しないだけなら新規作成して続行
            } else if let error = error as? CKError, error.code.rawValue == 15 {
                // エラー15 = サーバーがリクエストを拒否（一時障害のことが多い）
                if retryCount < 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.fetchRecordAndCreateShare(db: db, recordID: recordID, zoneID: zoneID, retryCount: retryCount + 1, completion: completion)
                    }
                    return
                }
                let msg = "CloudKit のサーバーで一時的なエラーが発生しました（エラー15）。\n代わりに「ルールをQRで表示」を使うと、CloudKit なしでルールを子に渡せます。"
                DispatchQueue.main.async { completion(nil, msg) }
                return
            } else if let error = error {
                let msg = "読み込みエラー: \(error.localizedDescription)\n代わりに「ルールをQRで表示」を使うと、CloudKit なしでルールを子に渡せます。"
                DispatchQueue.main.async { completion(nil, msg) }
                return
            }
            let recordToShare: CKRecord
            if let record = record {
                recordToShare = record
                record[CloudKitConfig.keyMinutes] = self.rule.dailyLimitMinutes
            } else {
                recordToShare = CKRecord(recordType: CloudKitConfig.recordType, recordID: recordID)
                recordToShare[CloudKitConfig.keyMinutes] = self.rule.dailyLimitMinutes
            }
            // レコードを保存してから、ゾーン単位の共有（CKShare(recordZoneID:)）を作成する
            self.saveRecordThenCreateZoneShare(db: db, record: recordToShare, retryCount: retryCount, recordID: recordID, zoneID: zoneID, completion: completion)
        }
    }

    /// レコードを保存してから、ゾーン単位の共有を作成する（rootRecord 方式でエラー15が続く場合の代替）。
    private func saveRecordThenCreateZoneShare(db: CKDatabase, record: CKRecord, retryCount: Int, recordID: CKRecord.ID, zoneID: CKRecordZone.ID, completion: @escaping (URL?, String?) -> Void) {
        db.save(record) { [weak self] _, saveError in
            guard let self = self else { return }
            if let saveError = saveError as? CKError, saveError.code.rawValue == 15, retryCount < 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.fetchRecordAndCreateShare(db: db, recordID: recordID, zoneID: zoneID, retryCount: retryCount + 1, completion: completion)
                }
                return
            }
            if let saveError = saveError {
                let msg = (saveError.localizedDescription) + "\n代わりに「ルールをQRで表示」を使うと、CloudKit なしでルールを子に渡せます。"
                DispatchQueue.main.async { completion(nil, msg) }
                return
            }
            self.createZoneShare(db: db, zoneID: zoneID, completion: completion)
        }
    }

    /// ゾーン単位の共有（CKShare(recordZoneID:)）を作成する。レコード単位の共有でエラー15になる場合に試す。
    private func createZoneShare(db: CKDatabase, zoneID: CKRecordZone.ID, completion: @escaping (URL?, String?) -> Void) {
        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = "ChildGuard のルール"
        share.publicPermission = .none
        let op = CKModifyRecordsOperation(recordsToSave: [share], recordIDsToDelete: nil)
        op.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                DispatchQueue.main.async { completion(share.url, nil) }
            case .failure(let error):
                let ckError = error as? CKError
                let msg: String
                if ckError?.code.rawValue == 15 {
                    msg = "CloudKit のサーバーで一時的なエラーが発生しました（エラー15）。\n代わりに「ルールをQRで表示」を使うと、CloudKit なしでルールを子に渡せます。"
                } else {
                    msg = (error.localizedDescription.isEmpty ? "共有の作成に失敗しました。" : error.localizedDescription) + "\n代わりに「ルールをQRで表示」を使うと、CloudKit なしでルールを子に渡せます。"
                }
                DispatchQueue.main.async { completion(nil, msg) }
            }
        }
        db.add(op)
    }

    /// QR で渡されたルール（childguard://rule?minutes=...）を反映する。CloudKit を使わない代替用。
    func applyRuleFromQR(dailyLimitMinutes: Int) {
        guard dailyLimitMinutes > 0 else { return }
        rule = Rule(dailyLimitMinutes: dailyLimitMinutes)
        saveToUserDefaults()
        if !isRunningInPreview { saveToCloudKit() }
    }

    /// 共有 URL を受け取ってルールを反映する（子側で呼ぶ）。
    func acceptShare(metadata: CKShare.Metadata, completion: @escaping (Bool) -> Void) {
        guard let container = container else {
            DispatchQueue.main.async { completion(false) }
            return
        }
        container.accept(metadata) { [weak self] _, error in
            guard let self = self, error == nil else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            if let rootRecord = metadata.rootRecord,
               let minutes = rootRecord[CloudKitConfig.keyMinutes] as? Int {
                DispatchQueue.main.async {
                    self.rule = Rule(dailyLimitMinutes: minutes)
                    self.saveToUserDefaults()
                    completion(true)
                }
            } else {
                DispatchQueue.main.async { completion(false) }
            }
        }
    }
}

