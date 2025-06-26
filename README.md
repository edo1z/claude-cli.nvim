# claude-cli.nvim

Seamlessly integrate Claude Code CLI into your Neovim workflow.

https://github.com/user-attachments/assets/7a96fad4-ade7-4a7a-88b4-d7cb8a96f84a

## Features

- 🤖 **Embedded Claude Code Terminal** - Run Claude Code directly in Neovim
- 📝 **Smart Prompt Builder** - Compose prompts with snippets and history
- 🔍 **Context Awareness** - Send file paths, errors, and code selections
- ⚡ **Quick Actions** - Fast keybindings for common tasks
- 💾 **Persistent Storage** - Save snippets and command history
- 🚀 **Dangerous Mode** - Skip permissions when needed
- 🔄 **Auto-reload Files** - Automatically updates files modified by Claude Code (built-in)
- 🔗 **Session Continuation** - Continue from the last Claude Code session with `-c` flag
- 👁️ **Window Toggle** - Show/hide Claude Code window without closing the session

## Requirements

- Neovim >= 0.7.0
- [Claude Code CLI](https://claude.ai/code) installed and configured

## Installation

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'edo1z/claude-cli.nvim'
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use 'edo1z/claude-cli.nvim'
```

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'edo1z/claude-cli.nvim',
  config = function()
    require('claude-cli').setup()
  end,
}
```

## Quick Start

### Session Management
Claude CLI for Neovim manages **one active session at a time**. Here's how it works:

1. **Smart Toggle**: `<leader>cc` / `<leader>cd`
   - **First press**: Starts a new Claude Code session
   - **Subsequent presses**: Toggles window visibility (keeps session active)
   - `<leader>cd` adds `--dangerously-skip-permissions` flag

2. **Force New Session (with continuation)**: `<leader>cC` / `<leader>cD`
   - Always closes existing session and starts fresh with `-c` flag
   - Useful when you want to continue from last Claude conversation
   - `<leader>cD` adds dangerous mode

3. **Explicit Window Toggle**: `<leader>ct`
   - Only toggles window visibility
   - Shows message if no active session exists

### Context Actions
1. Open prompt builder: `<leader>ca`
2. Send current error: `<leader>ce`
3. Send file path: `<leader>cp`
4. Send selection: `<leader>cs` (visual mode)

## Prompt Builder Features

When in the prompt builder (`<leader>ca`):

| Key | Action |
|-----|--------|
| `Ctrl+s` | Send to Claude Code |
| `Ctrl+l` | Show snippets |
| `Ctrl+h` | Show history |
| `Ctrl+c` | Create snippet |
| `Esc` | Close prompt |

In snippet/history list:
- `j/k`: Navigate
- `Enter/l`: Select
- `d`: Delete
- `e`: Edit (snippets only)
- `a`: Add new snippet (snippets list only)
- `s`: Save to snippet (history only)

## Configuration

```lua
require('claude-cli').setup({
  keymaps = {
    toggle = "<leader>cc",                 -- New session or toggle window
    toggle_dangerous = "<leader>cd",       -- New session or toggle (dangerous mode)
    continue_session = "<leader>cC",       -- Continue last session
    continue_session_dangerous = "<leader>cD", -- Continue last session dangerous
    toggle_window = "<leader>ct",          -- Toggle window visibility
    send_path = "<leader>cp",              -- Send file path to prompt
    send_error = "<leader>ce",             -- Send error info to prompt
    send_selection = "<leader>cs",         -- Send selection to prompt
    open_prompt = "<leader>ca",            -- Open prompt builder
  },
  window = {
    position = "right",  -- right, left, bottom, top
    size = 0.4,         -- 40% of screen
  },
  snippets = {
    Refactor = "このコードをリファクタリングして、より読みやすくしてください:\n",
    Explain = "このコードの動作を日本語で説明してください:\n",
    FixError = "以下のエラーを修正してください:\n",
    AddTests = "このコードに対するテストを作成してください:\n",
    Optimize = "このコードのパフォーマンスを最適化してください:\n",
  }
})

require('claude-prompt').setup({
  -- Prompt builder settings
  snippets_dir = vim.fn.stdpath('data') .. '/claude-prompt/snippets',
  history_dir = vim.fn.stdpath('data') .. '/claude-prompt/history',
  max_history = 100,
})
```

## Commands

- `:ClaudeCode` - Start new Claude Code session
- `:ClaudeCodeDangerous` - Start new session with dangerous mode
- `:ClaudeCodeContinue` - Continue last Claude Code session
- `:ClaudeCodeContinueDangerous` - Continue last session with dangerous mode
- `:ClaudeCodeToggle` - Toggle window visibility (keep session)
- `:ClaudePrompt` - Toggle prompt builder

## Snippets Management

Claude CLI for Neovim includes a powerful snippet system for commonly used prompts:

### Using Snippets

1. **From Prompt Builder**: Press `Ctrl+l` while in the prompt builder to view and select snippets
2. **Create New Snippet**: 
   - From prompt builder: Press `Ctrl+c`
   - From snippet list: Press `a`
3. **Edit Snippets**: Press `e` on a snippet in the list
4. **Delete Snippets**: Press `d` on a snippet in the list

### Default Snippets

The plugin comes with useful default snippets:
- **Refactor**: Ask Claude to refactor code for readability
- **Explain**: Get explanations for code in Japanese
- **FixError**: Request error fixes
- **AddTests**: Generate tests for code
- **Optimize**: Optimize code performance

### Custom Snippets

You can add custom snippets in two ways:

1. Through the configuration:
```lua
require('claude-cli').setup({
  snippets = {
    MySnippet = "My custom prompt text:\n",
    -- Add more snippets here
  }
})
```

2. Programmatically:
```lua
require('claude-cli').add_snippet("MySnippet", "My custom prompt text:\n")
```

## Tips

1. **Terminal Navigation**: Use `Ctrl+h/j/k/l` to move between windows from Claude terminal
2. **Exit Terminal Mode**: Press `Esc Esc` to enter normal mode
3. **Auto-reload**: Files modified by Claude Code are automatically reloaded when you return to Neovim
4. **Project Root**: Claude Code always starts in your project root directory
5. **Session Management**: 
   - Only one Claude session can be active at a time
   - `<leader>cc`/`<leader>cd` intelligently toggle window after first use
   - Starting a new session requires uppercase variants or closing current session
6. **Quick Workflow**:
   - Start work: `<leader>cc`
   - Hide/show during work: `<leader>cc` again (or `<leader>ct`)
   - Continue from last conversation: `<leader>cC`

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contributing

Issues and PRs are welcome!

## Acknowledgments

Built for use with [Claude Code](https://claude.ai/code) by Anthropic.
