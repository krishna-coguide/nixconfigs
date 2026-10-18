# Laptop-only local push-to-talk dictation (Voxtype, Parakeet engine).
# CPU ONNX Runtime by default; CUDA only where nvidia.nix enabled the driver.
# Imported from physical.nix only (not EC2 or the graphical test VM).
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  voxtype = inputs.voxtype.packages.${pkgs.stdenv.hostPlatform.system};
  # Not `default`: that build is Whisper-only. onnx-cuda falls back to CPU.
  package = if config.hardware.nvidia.enabled then voxtype.onnx-cuda else voxtype.onnx;

  # Parakeet TDT 0.6B v3 (int8), pinned to an upstream commit. Only the files
  # the loader reads; nemo128.onnx is unused (features are computed natively).
  revision = "8f23f0c03c8761650bdb5b40aaf3e40d2c15f1ce";
  model = pkgs.linkFarm "parakeet-tdt-0.6b-v3-int8" (
    lib.mapAttrsToList
      (name: hash: {
        inherit name;
        path = pkgs.fetchurl {
          url = "https://huggingface.co/istupakov/parakeet-tdt-0.6b-v3-onnx/resolve/${revision}/${name}";
          inherit hash;
        };
      })
      {
        "encoder-model.int8.onnx" = "sha256-YTnS+n4bCGCXsnfHFJcl7bq4nMfHrmSyPHQb5AVa/wk=";
        "decoder_joint-model.int8.onnx" = "sha256-7qdIPuPRowN12u3I7YPjlgyRsJiBISeg2Z0ciXdmenA=";
        "vocab.txt" = "sha256-1YVEZ56kvGrFY9H1Ret9R0vWz6Rn8KbiwdwcfTfjw10=";
      }
  );
in
{
  home-manager.users.dev = {
    imports = [ inputs.voxtype.homeManagerModules.default ];
    programs.voxtype = {
      enable = true;
      engine = "parakeet";
      inherit package;
      model.path = model; # Becomes parakeet.model; do not also set a name.
      service.enable = true;
      settings = {
        hotkey.enabled = false; # Hyprland binding below runs `voxtype record toggle`.
        parakeet = {
          model_type = "tdt"; # int8 file names defeat Voxtype's auto-detection.
          on_demand_loading = true; # Load on record, unload after; low idle RAM/VRAM.
        };
      };
    };
    wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
      bind("SUPER + V", hl.dsp.exec_cmd("${package}/bin/voxtype record toggle"), "Input · Dictation start / stop")
    '';
  };
}
