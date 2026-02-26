local pipx_python = vim.fn.expand("~/.local/pipx/venvs/pynvim/bin/python")

vim.g.python3_host_prog = pipx_python
vim.g.node_host_prog = "/opt/homebrew/bin/neovim-node-host"
vim.g.ruby_host_prog = "/opt/homebrew/lib/ruby/gems/4.0.0/bin/neovim-ruby-host"
vim.g.perl_host_prog = "/opt/homebrew/bin/perl"
vim.g.autoformat = false

vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.clipboard = ""
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
