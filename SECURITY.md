# セキュリティ・公開リポジトリの取り決め

このリポジトリは **GitHub 上で Public にする** 運用です。

## 仕様：public にしちゃダメなものは GitHub に載せない

以下は **絶対にコミット・プッシュしない** でください。すべて `.gitignore` で除外しています。

| 種別 | 例・パターン | 理由 |
|------|----------------|------|
| Firebase / Google | `GoogleService-Info.plist` | API キー・プロジェクト ID を含む |
| Apple 秘密鍵 | `*.p8`, `AuthKey_*.p8` | APNs / App Store Connect API 用 |
| 証明書・プロビジョニング | `*.cer`, `*.p12`, `*.mobileprovision` | 配布・署名に使用する秘密情報 |
| その他鍵 | `*.key`, `AppleDistribution.key` | 署名・認証に使用 |

- これらはローカルまたは CI の秘密変数でのみ扱い、リポジトリには含めません。
- 誤ってコミットした場合は、鍵・証明書のローテーションと、Git 履歴からの削除（必要なら `git filter-branch` 等）を検討してください。

## 報告

脆弱性や漏洩の疑いがある場合は、GitHub の Security タブから報告するか、リポジトリ管理者に非公開で連絡してください。
