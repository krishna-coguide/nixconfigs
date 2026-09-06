{ pkgs }:
{
  # Single source of truth: both pkgs.mkShell and the VM consume this attrset.
  # Replace/add your project's pinned toolchain here, not in two separate lists.
  packages = with pkgs; [
    python3
    uv
    ruff
    nodejs
    pnpm
    git
    ripgrep
  ];
  # Shared non-secret variables. Do not put API tokens in a Nix expression.
  env = {
    UV_PYTHON_DOWNLOADS = "never";
  };
}
