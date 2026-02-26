# ChildGuard を GitHub に繋ぐ手順

ローカルでは **git の初期化と初回コミットまで完了**しています。  
あとは GitHub にリポジトリを 1 つ作り、次の 2 コマンドを実行すれば push できます。

---

## 1. GitHub でリポジトリを新規作成

1. **https://github.com/new** を開く（ログインしていない場合はログイン）。
2. **Repository name**: `ChildGuard`（任意。別名でも可）
3. **Public** / **Private** はお好みで。
4. **「Add a README file」などにチェックを入れない**（すでに手元にコミットがあるため）。
5. **Create repository** をクリック。

---

## 2. 作成したリポジトリの URL を確認

作成後、表示される URL は次のどちらかです。

- **HTTPS**: `https://github.com/あなたのユーザー名/ChildGuard.git`
- **SSH**: `git@github.com:あなたのユーザー名/ChildGuard.git`

---

## 3. ターミナルで remote を追加して push

**ChildGuard のフォルダ**で、次のコマンドを実行してください。  
`あなたのユーザー名` の部分は、自分の GitHub ユーザー名に置き換えます。

**HTTPS の場合:**

```bash
cd /Users/a0011414/CloudStation/VariousPrograms/ChildGuard
git remote add origin https://github.com/あなたのユーザー名/ChildGuard.git
git push -u origin main
```

**SSH の場合（SSH キーを GitHub に登録済みなら）:**

```bash
cd /Users/a0011414/CloudStation/VariousPrograms/ChildGuard
git remote add origin git@github.com:あなたのユーザー名/ChildGuard.git
git push -u origin main
```

- 初回 `git push` で GitHub の認証（ブラウザまたはトークン）を求められたら、画面の指示に従ってください。
- 完了すると、GitHub のリポジトリページにコードが反映されています。

---

## 補足

- リポジトリ名を `ChildGuard` 以外にした場合は、上記の `ChildGuard` をその名前に変えてください。
- すでに `git remote add` を実行してしまった場合は、次のように上書きできます。  
  `git remote set-url origin https://github.com/あなたのユーザー名/リポジトリ名.git`
