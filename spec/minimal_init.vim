" Minimal init for tests
set rtp+=.
set rtp+=~/.local/share/nvim/site/pack/test/start/plenary.nvim

" Load lua path
lua << EOF
-- Add current plugin to lua path
package.path = vim.fn.getcwd() .. '/lua/?.lua;' .. package.path
package.path = vim.fn.getcwd() .. '/lua/?/init.lua;' .. package.path
EOF