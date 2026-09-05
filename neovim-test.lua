-- Native runtime audit, not a sandboxed Nix build: Lazy/Mason may download tools.
-- As dev: nvim --headless ~/.config/nvim/init.lua -c 'luafile /etc/nixos/neovim-test.lua'
-- No configuration edits or buffer writes; allow a cold bootstrap time to finish.
vim.defer_fn(function()
  local errors = {}
  local report = { lazy = require("lazy").stats(), colorscheme = vim.g.colors_name, mason = {}, parsers = {}, lsp = {} }
  local registry = require("mason-registry")
  for _, name in ipairs({ "lua-language-server", "stylua", "debugpy", "tree-sitter-cli", "clangd", "rust-analyzer" }) do
    local ok, package = pcall(registry.get_package, name)
    report.mason[name] = ok and package:is_installed() or false
    if not report.mason[name] then table.insert(errors, "Mason package missing: " .. name) end
  end
  for _, name in ipairs({ "bash", "c", "lua", "markdown", "markdown_inline", "python", "query", "vim", "vimdoc" }) do
    local ok = pcall(vim.treesitter.language.add, name)
    report.parsers[name] = ok
    if not ok then table.insert(errors, "Parser missing: " .. name) end
  end
  report.executables = {}
  local bin = require("mason.settings").current.install_root_dir .. "/bin/"
  for _, name in ipairs({ "lua-language-server", "stylua", "tree-sitter", "clangd", "rust-analyzer" }) do
    local result = vim.system({ bin .. name, "--version" }, { text = true }):wait(10000)
    report.executables[name] = result.code == 0
    if result.code ~= 0 then table.insert(errors, "Mason executable failed: " .. name) end
  end
  for _, client in ipairs(vim.lsp.get_clients()) do table.insert(report.lsp, client.name) end
  if vim.v.errmsg ~= "" then table.insert(errors, vim.v.errmsg) end
  report.errors = errors
  print("RUNTIME_REPORT=" .. vim.json.encode(report))
  vim.cmd(#errors == 0 and "qa" or "cquit 1")
end, tonumber(vim.env.NVIM_AUDIT_WAIT_MS) or 90000)
