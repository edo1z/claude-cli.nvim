# claude-cli.nvim

Seamlessly integrate Claude Code CLI into your Neovim workflow with multi-instance management.

https://github.com/user-attachments/assets/7a96fad4-ade7-4a7a-88b4-d7cb8a96f84a

## Features

- 🤖 **Embedded Claude Code Terminal** - Run Claude Code directly in Neovim
- 📝 **Smart Prompt Builder** - Compose prompts with snippets and history
- 🔍 **Context Awareness** - Send file paths, errors, and code selections
- ⚡ **Quick Actions** - Fast keybindings for common tasks
- 💾 **Persistent Storage** - Save snippets and command history
- 🚀 **Dangerous Mode** - Skip permissions when needed
- 🔄 **Auto-reload Files** - Automatically updates files modified by Claude Code
- 🔗 **Session Continuation** - Continue from the last Claude Code session
- 🎯 **Multi-Instance Manager** - Manage up to 30 Claude Code instances simultaneously

## Requirements

- Neovim >= 0.8.0
- [Claude Code CLI](https://claude.ai/code) installed and configured
- tmux (for multi-instance manager)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim) (Recommended)

```lua
{
  'edo1z/claude-cli.nvim',
  config = function()
    require('claude-cli').setup()
  end,
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'edo1z/claude-cli.nvim'
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use 'edo1z/claude-cli.nvim'
```

## Quick Start

### Single Instance Mode
1. Start Claude Code: `<leader>cc` (or `<leader>cd` for dangerous mode)
2. Toggle window visibility: `<leader>cc` again
3. Continue from last session: `<leader>cC`

### Multi-Instance Manager (New!)
1. Open instance manager: `<leader>cm`
2. Add new instance: press `a` in the list view
3. Open specific instance: press `o` on any instance
4. Delete instance: press `d` on selected instance

### Send Context to Claude
- Open prompt builder: `<leader>ca`
- Send current error: `<leader>ce`
- Send file path: `<leader>cp`
- Send selection: `<leader>cs` (visual mode)

## Multi-Instance Manager

The multi-instance manager allows you to run multiple Claude Code sessions simultaneously:

### Key Features
- **Dynamic Management**: Start with 0 instances, add up to 30 as needed
- **tmux Integration**: Each instance runs in a separate tmux session
- **Process Isolation**: Instances are namespaced by Neovim process ID
- **Launch Options**: Choose from normal, continue (-c), and dangerous modes

### List View Keybindings
| Key | Action |
|-----|--------|
| `a` | Add new instance with options |
| `d` | Delete current instance (with confirmation) |
| `o` | Open instance in individual window |
| `r` | Restart instance |
| `q` | Close list view |
| `?` | Show help |
| `<C-q>` | Exit terminal mode |

### Commands
- `:ClaudeManagerToggle` - Toggle instance list view
- `:ClaudeManagerShow` - Show instance list
- `:ClaudeManagerHide` - Hide instance list
- `:ClaudeManagerOpen [name]` - Open specific instance

## Prompt Builder

The prompt builder (`<leader>ca`) provides powerful prompt composition:

| Key | Action |
|-----|--------|
| `Ctrl+s` | Send to active Claude instance |
| `Ctrl+l` | Show snippets |
| `Ctrl+h` | Show history |
| `Ctrl+c` | Create snippet |
| `Esc` | Close prompt |

## Configuration

```lua
require('claude-cli').setup({
  keymaps = {
    -- Single instance mode
    toggle = "<leader>cc",
    toggle_dangerous = "<leader>cd",
    continue_session = "<leader>cC",
    continue_session_dangerous = "<leader>cD",
    toggle_window = "<leader>ct",
    
    -- Context actions
    send_path = "<leader>cp",
    send_error = "<leader>ce",
    send_selection = "<leader>cs",
    open_prompt = "<leader>ca",
    
    -- Multi-instance manager
    manager_toggle = "<leader>cm",
  },
  window = {
    position = "right",  -- right, left, bottom, top
    size = 0.4,         -- 40% of screen
  },
  snippets = {
    -- Default snippets
    Refactor = "このコードをリファクタリングして、より読みやすくしてください:\n",
    Explain = "このコードの動作を日本語で説明してください:\n",
    FixError = "以下のエラーを修正してください:\n",
    AddTests = "このコードに対するテストを作成してください:\n",
    Optimize = "このコードのパフォーマンスを最適化してください:\n",
  }
})
```

## Commands

### Single Instance
- `:ClaudeCode` - Start new Claude Code session
- `:ClaudeCodeDangerous` - Start with dangerous mode
- `:ClaudeCodeContinue` - Continue last session
- `:ClaudeCodeToggle` - Toggle window visibility
- `:ClaudePrompt` - Open prompt builder

### Multi-Instance Manager
- `:ClaudeManagerToggle` - Toggle instance list
- `:ClaudeManagerShow` - Show instance list
- `:ClaudeManagerHide` - Hide instance list
- `:ClaudeManagerOpen` - Open specific instance

## Tips

1. **Active Instance**: When using multi-instance manager, `<leader>ca` sends to the active instance
2. **Quick Switch**: Use `<leader>cm` to quickly switch between instances
3. **Terminal Navigation**: Use `Ctrl+q` to exit terminal mode in instance list
4. **Auto-reload**: Files modified by Claude are automatically reloaded
5. **Process Isolation**: Each Neovim process has its own set of Claude instances

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contributing

Issues and PRs are welcome!

## Acknowledgments

Built for use with [Claude Code](https://claude.ai/code) by Anthropic.