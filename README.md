# claude-cli.nvim

Seamlessly integrate Claude Code CLI into your Neovim workflow.

![claude-cli demo](https://user-images.githubusercontent.com/placeholder.gif)

## Features

- 🤖 **Embedded Claude Code Terminal** - Run Claude Code directly in Neovim
- 📝 **Smart Prompt Builder** - Compose prompts with snippets and history
- 🔍 **Context Awareness** - Send file paths, errors, and code selections
- ⚡ **Quick Actions** - Fast keybindings for common tasks
- 💾 **Persistent Storage** - Save snippets and command history
- 🚀 **Dangerous Mode** - Skip permissions when needed
- 🔄 **Auto-reload Files** - Automatically updates files modified by Claude Code (built-in)

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

1. Toggle Claude Code terminal: `<leader>cc`
2. Toggle with dangerous mode: `<leader>cd`
3. Open prompt builder: `<leader>ka`
4. Send current error: `<leader>ke`
5. Send file path: `<leader>kp`
6. Send selection: `<leader>ks` (visual mode)

## Prompt Builder Features

When in the prompt builder (`<leader>ka`):

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
- `s`: Save to snippet (history only)

## Configuration

```lua
require('claude-cli').setup({
  keymaps = {
    toggle = "<leader>cc",         -- Toggle Claude Code
    toggle_dangerous = "<leader>cd", -- Toggle with --dangerously-skip-permissions
  },
  window = {
    position = "right",  -- right, left, bottom, top
    size = 0.4,         -- 40% of screen
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

- `:ClaudeCode` - Toggle Claude Code terminal
- `:ClaudeCodeDangerous` - Toggle with dangerous mode
- `:ClaudePrompt` - Toggle prompt builder

## Tips

1. **Terminal Navigation**: Use `Ctrl+h/j/k/l` to move between windows from Claude terminal
2. **Exit Terminal Mode**: Press `Esc Esc` to enter normal mode
3. **Auto-reload**: Files modified by Claude Code are automatically reloaded when you return to Neovim
4. **Project Root**: Claude Code always starts in your project root directory

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contributing

Issues and PRs are welcome!

## Acknowledgments

Built for use with [Claude Code](https://claude.ai/code) by Anthropic.