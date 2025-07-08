# claude-cli.nvim

Neovimに Claude Code CLI をシームレスに統合し、マルチインスタンス管理を実現します。

https://github.com/user-attachments/assets/7a96fad4-ade7-4a7a-88b4-d7cb8a96f84a

## 特徴

- 🤖 **組み込みClaude Codeターミナル** - NeovimでClaude Codeを直接実行
- 📝 **スマートプロンプトビルダー** - スニペットと履歴でプロンプトを構築
- 🔍 **コンテキスト認識** - ファイルパス、エラー、コード選択を送信
- ⚡ **クイックアクション** - 一般的なタスクの高速キーバインディング
- 💾 **永続的ストレージ** - スニペットとコマンド履歴を保存
- 🔄 **ファイル自動リロード** - Claude Codeが変更したファイルを自動的に更新
- 🔗 **セッション継続** - 最後のClaude Codeセッションから継続
- 🎯 **マルチインスタンスマネージャー** - 最大30個のClaude Codeインスタンスを同時管理

## 必要要件

- Neovim >= 0.8.0
- [Claude Code CLI](https://claude.ai/code) がインストールされ設定済み
- tmux（マルチインスタンスマネージャー用）

## インストール

### [lazy.nvim](https://github.com/folke/lazy.nvim) を使用（推奨）

```lua
{
  'edo1z/claude-cli.nvim',
  config = function()
    require('claude-cli').setup()
  end,
}
```

### [vim-plug](https://github.com/junegunn/vim-plug) を使用

```vim
Plug 'edo1z/claude-cli.nvim'
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim) を使用

```lua
use 'edo1z/claude-cli.nvim'
```

## クイックスタート

### 基本的な使い方
1. 新しいClaude Codeセッションを開始: `<leader>cc`（Dangerousモードは `<leader>cd`）
2. 前回のセッションから継続: `<leader>cC`（Dangerousモードは `<leader>cD`）
3. インスタンスマネージャーを開く: `<leader>cm`

### マルチインスタンスマネージャー
1. インスタンスマネージャーを開く: `<leader>cm`
2. 新しいインスタンスを追加: リストビューで `a` を押す
3. 特定のインスタンスを開く: 任意のインスタンスで `o` を押す
4. インスタンスを削除: 選択したインスタンスで `d` を押す

### Claudeにコンテキストを送信
- プロンプトビルダーを開く: `<leader>ca`
- 現在のエラーを送信: `<leader>ce`
- ファイルパスを送信: `<leader>cp`
- 選択箇所を送信: `<leader>cs`（ビジュアルモード）

## マルチインスタンスマネージャー

マルチインスタンスマネージャーは、複数のClaude Codeセッションを同時に実行できます：

### 主な機能
- **動的管理**: 0個のインスタンスから開始し、必要に応じて最大30個まで追加
- **tmux統合**: 各インスタンスは個別のtmuxセッションで実行
- **プロセス分離**: インスタンスはNeovimプロセスIDで名前空間化
- **起動オプション**: 通常、継続（-c）、Dangerousモードから選択

### リストビューのキーバインディング
| キー | アクション |
|-----|--------|
| `a` | 新しいインスタンスを追加 |
| `d` | 現在のインスタンスを削除（確認付き） |
| `o` | インスタンスを個別ウィンドウで開く |
| `q` | リストビューを閉じる |
| `?` | ヘルプを表示 |
| `<C-q>` | ターミナルモードを終了 |

### コマンド
- `:ClaudeManagerToggle` - インスタンスリストビューを切り替え
- `:ClaudeManagerShow` - インスタンスリストを表示
- `:ClaudeManagerHide` - インスタンスリストを非表示
- `:ClaudeManagerOpen [名前]` - 特定のインスタンスを開く

## プロンプトビルダー

プロンプトビルダー（`<leader>ca`）は強力なプロンプト構築機能を提供します：

| キー | アクション |
|-----|--------|
| `Ctrl+s` | アクティブなClaudeインスタンスに送信 |
| `Ctrl+l` | スニペットを表示 |
| `Ctrl+h` | 履歴を表示 |
| `Ctrl+c` | スニペットを作成 |
| `Esc` | プロンプトを閉じる |

## 設定

```lua
require('claude-cli').setup({
  keymaps = {
    -- 基本キーマップ
    toggle = "<leader>cc",
    toggle_dangerous = "<leader>cd",
    continue_session = "<leader>cC",
    continue_session_dangerous = "<leader>cD",
    
    -- コンテキストアクション
    send_path = "<leader>cp",
    send_error = "<leader>ce",
    send_selection = "<leader>cs",
    open_prompt = "<leader>ca",
    
    -- マルチインスタンスマネージャー
    manager_toggle = "<leader>cm",
  },
  window = {
    position = "right",  -- right, left, bottom, top
    size = 0.4,         -- 画面の40%
  },
  snippets = {
    -- デフォルトスニペット
    Refactor = "このコードをリファクタリングして、より読みやすくしてください:\n",
    Explain = "このコードの動作を日本語で説明してください:\n",
    FixError = "以下のエラーを修正してください:\n",
    AddTests = "このコードに対するテストを作成してください:\n",
    Optimize = "このコードのパフォーマンスを最適化してください:\n",
  }
})
```

## コマンド

### 基本コマンド
- `:ClaudeCode` - 新しいClaude Codeセッションを開始
- `:ClaudeCodeDangerous` - Dangerousモードで開始
- `:ClaudeCodeContinue` - 最後のセッションを継続
- `:ClaudePrompt` - プロンプトビルダーを開く

### マルチインスタンスマネージャー
- `:ClaudeManagerToggle` - インスタンスリストを切り替え
- `:ClaudeManagerShow` - インスタンスリストを表示
- `:ClaudeManagerHide` - インスタンスリストを非表示
- `:ClaudeManagerOpen` - 特定のインスタンスを開く

## ヒント

1. **アクティブインスタンス**: マルチインスタンスマネージャー使用時、`<leader>ca` はアクティブなインスタンスに送信します
2. **クイック切り替え**: `<leader>cm` でインスタンス間を素早く切り替え
3. **ターミナルナビゲーション**: インスタンスリストでターミナルモードを終了するには `Ctrl+q` を使用
4. **自動リロード**: Claudeが変更したファイルは自動的にリロードされます
5. **プロセス分離**: 各Neovimプロセスには独自のClaudeインスタンスセットがあります

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) ファイルを参照してください。

## 貢献

IssueとPRを歓迎します！

## 謝辞

Anthropicの [Claude Code](https://claude.ai/code) で使用するために構築されました。