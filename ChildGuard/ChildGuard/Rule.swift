//
//  Rule.swift
//  ChildGuard
//
//  最小のルールモデル：「1日〇分まで」。UserDefaults で保存。子への受け渡しは QR（childguard://）のみ。
//

import Foundation
import Combine

/// プロトタイプで使う1本のルール。「1日の利用時間の上限（分）」だけを持つ。
struct Rule: Codable, Equatable {
    /// 1日の利用時間の上限（分）。0 は「未設定」とする。
    var dailyLimitMinutes: Int
}

// MARK: - 保存・読み込み（UserDefaults）

private let key = "childguard_rule"

final class RuleStore: ObservableObject {
    @Published var rule: Rule {
        didSet { save() }
    }

    init() {
        self.rule = RuleStore.loadFromUserDefaults()
    }

    private func save() {
        saveToUserDefaults()
    }

    // MARK: - UserDefaults（ローカル）

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

    // MARK: - QR で渡されたルール（childguard://rule?minutes=...）

    /// QR で渡されたルールを反映する。
    func applyRuleFromQR(dailyLimitMinutes: Int) {
        guard dailyLimitMinutes > 0 else { return }
        rule = Rule(dailyLimitMinutes: dailyLimitMinutes)
        saveToUserDefaults()
    }
}
