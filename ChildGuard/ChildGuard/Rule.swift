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
    static let zoneName = "ChildGuardRules"
    static let recordType = "Rule"
    static let recordName = "currentRule"
    static let keyMinutes = "dailyLimitMinutes"
}

/// Preview 実行中かどうか（CloudKit をスキップしてクラッシュを防ぐ）
private var isRunningInPreview: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}

/// iCloud が利用可能なときだけ true（CKContainer.default() を呼ばずに判定）
private var canUseCloudKit: Bool {
    !isRunningInPreview && FileManager.default.ubiquityIdentityToken != nil
}

final class RuleStore: ObservableObject {
    @Published var rule: Rule {
        didSet { save() }
    }

    /// iCloud 利用可能なときだけ作成。それ以外では nil のまま（UserDefaults のみ使用）
    private lazy var container: CKContainer? = {
        guard canUseCloudKit else { return nil }
        return CKContainer.default()
    }()
    private var zoneID: CKRecordZone.ID?

    init() {
        self.rule = RuleStore.loadFromUserDefaults()
        if !isRunningInPreview {
            fetchFromCloudKit()
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
            self.zoneID = zoneID
            let recordID = CKRecord.ID(recordName: CloudKitConfig.recordName, zoneID: zoneID)
            db.fetch(withRecordID: recordID) { record, error in
                guard let record = record,
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
            self.zoneID = zoneID
            let recordID = CKRecord.ID(recordName: CloudKitConfig.recordName, zoneID: zoneID)
            let record = CKRecord(recordType: CloudKitConfig.recordType, recordID: recordID)
            record[CloudKitConfig.keyMinutes] = self.rule.dailyLimitMinutes
            db.save(record) { _, _ in }
        }
    }

    private func ensureZoneExists(in db: CKDatabase, completion: @escaping (CKRecordZone.ID?) -> Void) {
        let zoneID = CKRecordZone.ID(zoneName: CloudKitConfig.zoneName, ownerName: CKCurrentUserDefaultName)
        let zone = CKRecordZone(zoneID: zoneID)
        db.save(zone) { _, error in
            // 成功時は zoneID を返す。失敗時も「既に存在」の可能性があるため zoneID を返し、後続の fetch/save に任せる。
            completion(zoneID)
        }
    }

    // MARK: - 親→子共有（CKShare）

    /// ルールを子どもと共有するための URL を用意する。完了時に main で callback が呼ばれる。Preview では何もしない。
    func prepareShareURL(completion: @escaping (URL?) -> Void) {
        if isRunningInPreview {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        guard let container = container else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        let db = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: CloudKitConfig.zoneName, ownerName: CKCurrentUserDefaultName)
        let recordID = CKRecord.ID(recordName: CloudKitConfig.recordName, zoneID: zoneID)
        db.fetch(withRecordID: recordID) { [weak self] record, error in
            guard let self = self, let record = record else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            record[CloudKitConfig.keyMinutes] = self.rule.dailyLimitMinutes
            let share = CKShare(rootRecord: record)
            share[CKShare.SystemFieldKey.title] = "ChildGuard のルール"
            share.publicPermission = .none
            let op = CKModifyRecordsOperation(recordsToSave: [record, share], recordIDsToDelete: nil)
            op.modifyRecordsResultBlock = { result in
                let url: URL?
                if case .success = result { url = share.url } else { url = nil }
                DispatchQueue.main.async { completion(url) }
            }
            db.add(op)
        }
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

