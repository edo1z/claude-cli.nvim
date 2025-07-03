# Claude Code Multi-Instance Manager 開発ガイド

## 重要事項

### 開発プロセス
- **TDD（テスト駆動開発）**: t-wada流のTDDで開発を進める
  1. Red: 失敗するテストを書く
  2. Green: テストを通す最小限の実装
  3. Refactor: コードを改善
- **コミット粒度**: 機能単位で小まめにコミット
- **品質保証**:
  - コミット前に全てのテストがパスすることを確認
  - テストをパスさせるための無益な修正は行わない
  - LSPツールで修正したファイルをチェックし、エラー・警告を修正
- **コミット後**: `/compact`を実行

### テスト方針
- 全てのコードにユニットテストを作成
- テストフレームワーク: **Plenary Busted** を使用
- テストファイルは `spec/` ディレクトリに配置
- ファイル名は `*_spec.lua` の形式

### コーディング規約
- Luaのコーディングスタイルに従う
- モジュール間の疎結合を維持
- エラーハンドリングを徹底
- 非同期処理にはvim.loopを使用

### Git管理
- 現在のブランチ: `feature/tmux-manager`
- コミットは機能単位で細かく行う
- **プッシュは明示的に指示があるまで行わない**

### 実装の進め方
1. `docs/implementation-plan.md` の計画に従って進める
2. 各タスク完了時に計画書の進捗を更新
3. 実装前に既存コードの構造を理解する
4. テストを同時に作成する

### ディレクトリ構造
```
claude-cli.nvim/
├── lua/
│   ├── claude-cli/           # 既存のCLI管理
│   ├── claude-prompt/        # 既存のプロンプト管理
│   └── claude-manager/       # 新規：マネージャーモジュール
│       ├── init.lua          # メインマネージャー
│       ├── tmux.lua          # tmuxセッション管理
│       ├── ui_list.lua       # 一覧画面UI
│       ├── ui_individual.lua # 個別ウィンドウUI
│       └── state.lua         # 状態管理
├── spec/                     # テストディレクトリ
│   └── claude-manager/
│       ├── tmux_spec.lua
│       ├── ui_list_spec.lua
│       ├── ui_individual_spec.lua
│       └── ...
└── docs/
    ├── multi-instance-manager-design.md
    └── implementation-plan.md
```

### 参考リンク
- 設計書: `/docs/multi-instance-manager-design.md`
- 実装計画: `/docs/implementation-plan.md`
- 参考実装: https://github.com/edo1z/nvim-tmux-test

