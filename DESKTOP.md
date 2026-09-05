# Desktop research and proposed baseline

Researched **2026-09-05 UTC**. **This is a proposal, not an installed desktop.** Hyprland and Firefox are selected; the supporting applications below are recommendations for review. No desktop, authentication, driver or input-lock changes have been activated.

The comparison uses the current official NixOS Wiki, upstream documentation/release notes, project screenshots, and the actual package/module sources locked by this repository:

- Nixpkgs: `d57af924f160a5084293c71c2043f058bd1cdb60`.
- Home Manager: `65258d5c65a250189fde2e35f490d15e064c4c62`.
- Package versions below are **available in that pin**, not necessarily current upstream releases. Screenshots illustrate upstream styling, not a locally tested session or a promise that every pictured feature exists in our pin.

## Recommended small desktop

| Role | Recommendation | Pinned version | Rationale / trade-off |
| --- | --- | --- | --- |
| Compositor/session | Hyprland + UWSM | 0.55.4 / 0.26.4 | Selected compositor; native NixOS session integration, with one owner for systemd startup/shutdown. |
| Browser | Firefox | 154.0.1 | Selected browser; keep its sandbox and ordinary browser configuration. Update freshness needs attention below. |
| Terminal | **Alacritty** (Rust) | 0.17.0 | Focused terminal with native Wayland support. No built-in tabs/splits; Hyprland already arranges windows. Ghostty 1.3.1 (Zig) is the richer alternative if terminal tabs, splits or image protocols are wanted. |
| Bar/quick settings | **ashell** (Rust/Iced) | 0.8.0 | Rounded, ready-made bar with workspaces, tray, audio controls and settings; avoids building a shell from widgets. Ironbar 0.19.0 (Rust/GTK4) is preferable for more bespoke panels/CSS. |
| Launcher | **Anyrun** (Rust/GTK4) | 25.12.0 | Application search with optional calculator/symbol plugins; enable only useful plugins, not indexing/network integrations by default. Fuzzel 1.14.1 (C) is the simpler alternative with a direct launch-prefix option. |
| Lock/idle | **hyprlock + hypridle** (C++) | 0.9.5 / 0.1.7 | Hyprland-native integration, PAM, session-lock protocol and lock-completion-aware sleep inhibition. Security and recovery matter more than implementation language here. |
| Notifications | **mako** (C) | 1.11.0 | Small, styleable notification daemon. SwayNotificationCenter 0.12.6 (Vala) adds a full notification drawer if that is wanted later. |
| Privilege prompts | **hyprpolkitagent** | 0.1.3 | Existing Home Manager session-bound integration. Soteria 0.3.1 is a genuine Rust alternative, but has session-registration considerations and a newer restart-related fix upstream. |
| Audio/screensharing | PipeWire + WirePlumber; Hyprland and GTK portals | — | Audio, screen capture and file-picker plumbing, not optional decoration. Use native NixOS modules. |
| Clipboard/screenshots | wl-clipboard; grim + slurp; **Satty** (Rust) for annotation | 2.3.0 / 1.5.0 / 1.5.0 / 0.20.1 | Normal copy/paste and area capture; annotation runs on demand. No persistent clipboard history by default. |

Use a small font/icon set, restrained dark colors, modest rounding and short animations. Do not add a theme framework, custom shell framework, downloaded startup scripts, weather accounts or a second bar. This does not change the Neovim theme or any Neovim source.

**Optional wallpaper tool:** [awww](https://codeberg.org/LGFae/awww), Rust, pinned 0.12.1, if image switching/transitions are wanted. The old `swww` GitHub repository is archived and explicitly redirects to this renamed project; Nixpkgs warns about the old attribute. A solid background does not need another daemon.

Visual references: [ashell gallery](https://github.com/MalpenZibo/ashell#-screenshots), [Ironbar examples](https://github.com/JakeStanger/ironbar), [Anyrun](https://github.com/anyrun-org/anyrun), [Sherlock](https://github.com/Skxxtz/sherlock), [Veila](https://github.com/naurissteins/Veila). The reviewed ashell design uses compact rounded groups and popovers; Ironbar's minimal example is a flatter, denser strip. Both are legitimate aesthetic choices.

## Rust screen lockers: real candidates, not a blanket dismissal

- **Veila** is an attractive, standalone Rust option using `ext-session-lock-v1`, with a packaged build in this Nixpkgs. However, the pin has **0.4.0** and upstream **0.4.4** explicitly lists password-memory handling, daemon-authorized unlock, and fail-closed unlock-handoff fixes. Do **not** select the older package merely to keep the desktop Rust-based. Its daemon and PAM setup must also be declared. [0.4.4 release notes](https://github.com/naurissteins/Veila/releases/tag/0.4.4).
- **Cthulock** is Rust/Slint with a configurable UI and the same session-lock protocol. Latest observed release: 0.1.2, 2025-08-31. Its upstream Nix integration is an additional flake rather than a package/module already present in this pin. It is a possible experiment, not the lowest-maintenance baseline. [Project](https://github.com/FriederHannenheim/cthulock).
- **veiland** is a newer Rust locker with process-isolated GPU plugins, including upstream reports of NVIDIA suspend/hotplug testing. That is upstream evidence, not our testing. Its extensible scene/plugin architecture is more than this minimal desktop needs. [Project](https://github.com/sylflo/veiland).
- **hyprlock** remains the recommendation, not a claim of audited or bug-free software. Its newer 0.9.6 release also contains PAM, rendering and output-handling fixes; review it when refreshing the pin. [Release notes](https://github.com/hyprwm/hyprlock/releases/tag/v0.9.6).

The important property is a compositor-enforced lock, not a fullscreen password window. The [Wayland session-lock protocol](https://wayland.app/protocols/ext-session-lock-v1) requires the session to stay locked if the locker dies after acquiring the lock. It does not prevent authentication bugs in a client, guarantee successful initial locking, or protect against every compositor/GPU failure.

**Login is separate:** ReGreet and tuigreet are Rust greeters for greetd, not screen lockers. ReGreet is the graphical option; tuigreet is the smaller terminal option. A display manager remains a separate choice, not a silent addition to the EC2 host. COSMIC's greeter is not a drop-in Hyprland locker.

## Compatibility details that affect implementation

1. **Use the new Hyprland configuration format.** The [current NixOS Wiki](https://wiki.nixos.org/wiki/Hyprland) explicitly flags its older examples as outdated: Hyprland 0.55 introduced Lua configuration. Our locked Home Manager defaults to `configType = "lua"` for `home.stateVersion = "26.05"`. Write a small native `hyprland.lua`, using the [0.55.4 example/API](https://github.com/hyprwm/Hyprland/blob/v0.55.4/example/hyprland.lua), rather than copying old `bind = ...` examples into Lua settings. Do not change stateVersion to work around this.
2. **Only one session manager.** NixOS recommends `programs.hyprland.withUWSM = true`; disable Home Manager's separate Hyprland systemd integration. Upstream also warns UWSM adds its own quirks. Bind bar/agent services to the graphical session and launch applications through the session manager. [Session documentation](https://wiki.hypr.land/Useful-Utilities/Systemd-start/).
3. **ashell needs small but important overrides.** Its pinned default logout command is `loginctl kill-user $(whoami)`, which is broader than logging out of the desktop and could terminate other sessions. Use `uwsm stop`. The pinned Home Manager service has startup ordering but no `PartOf`; explicitly tie its lifetime to `graphical-session.target`. Version 0.8 does not advertise the notification manager shown in the current 0.10 README, so do not assume it replaces mako. [Pinned settings](https://github.com/MalpenZibo/ashell/blob/0.8.0/website/versioned_docs/version-0.8.0/configuration/modules/settings.md).
4. **Rust does not eliminate NVIDIA rendering issues.** ashell 0.8 documents startup freezes with the Vulkan backend and an application-scoped `WGPU_BACKEND=gl` workaround. Anyrun documents a driver-dependent GTK close/hang problem and `GSK_RENDERER=ngl`. Test the actual target first; apply a needed workaround only to that application on that target. Do not export these globally to integrated-graphics machines. [ashell troubleshooting](https://github.com/MalpenZibo/ashell/blob/0.8.0/website/versioned_docs/version-0.8.0/configuration/troubleshooting.md), [Anyrun warning](https://github.com/anyrun-org/anyrun#anyrun).
5. **Anyrun's provider is already packaged correctly.** Since 25.12 it needs `anyrun-provider`; our Nixpkgs wrapper supplies it and the plugin search path. Do not add a manual Cargo install or another flake. The applications plugin searches desktop entries, and its version-specific preprocessing hook must be used when arranging UWSM application launching.
6. **Do not install the wrong Sherlock.** The Rust launcher is `pkgs.sherlock-launcher` (0.1.14-3), and `programs.sherlock` in Home Manager correctly selects it. `pkgs.sherlock` (0.16.0) is an unrelated Python social-account search tool. Sherlock has a polished widget-style UI, but Anyrun/Fuzzel are a more focused starting point.
7. **Portals and idle services already have system integration.** The pinned NixOS Hyprland module adds both Hyprland and GTK portals; the latter supplies a file picker. Do not install competing portal stacks or add sleep/kill/restart hacks. The NixOS hyprlock module creates its PAM service and enables the system-provided hypridle user unit; Home Manager can supply idle configuration with `package = null` instead of creating another unit. A valid lock configuration is required: installing a locker is not enough.
8. **Wait for locking, not an arbitrary delay.** The pinned hypridle supports `general.inhibit_sleep = 3`, waiting for Hyprland's lock notification before releasing its sleep inhibitor, subject to logind's inhibitor timeout. It does not support the newer conditional-timeout options in current upstream documentation. Configure idle lock/display-off without silently adding automatic suspend to a development host. [hypridle documentation](https://wiki.hypr.land/Hypr-Ecosystem/hypridle/).

## RTX 4090 versus integrated graphics

Keep the shared desktop separate from a deliberately imported `nvidia.nix`. Do not put NVIDIA options/environment variables into every machine's common module, invent PRIME bus IDs, or reuse EC2's boot/storage configuration on a workstation.

- **Intel/AMD-only targets:** start with the standard kernel/Mesa graphics stack. Device-generation-specific video decoding or firmware adjustments require actual hardware identification.
- **RTX 4090 target:** NVIDIA's open kernel modules support Ada/RTX 4090. Use the NixOS driver module with `hardware.nvidia.open = true`, modesetting and power-management support. The userspace driver remains proprietary and needs a scoped unfree allowance. `services.xserver.videoDrivers = [ "nvidia" ]` selects the driver even for Wayland; this does not require enabling the X server.
- **Pinned driver:** stable and production both resolve to **595.71.05**. With open modules, the pinned NixOS module selects the new **kernel suspend notifier** path. Enabling power management sets the appropriate module parameters without the legacy `nvidia-suspend`/`nvidia-resume` services. Do not unconditionally paste older service recipes on top.
- **Suspend storage:** NVIDIA recommends enough temporary backing storage for total VRAM plus about 5%; a 24-GiB 4090 needs roughly 25.2 GiB in the conservative worst case. Check the target filesystem and `/tmp` policy before promising reliable suspend. Do not force early KMS or hibernation configuration without checking the machine.
- **Firefox video decoding is a separate question.** The NVIDIA VA-API bridge's documented setup disables Firefox's RDD sandbox. Do not silently adopt that security trade-off for hardware video decoding. Native Wayland rendering and hardware video decoding are not the same feature.

Sources: [official NixOS NVIDIA page](https://wiki.nixos.org/wiki/NVIDIA), [Hyprland NVIDIA guidance](https://wiki.hypr.land/Nvidia/), [NVIDIA supported GPUs](https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus), [595.71.05 power-management documentation](https://download.nvidia.com/XFree86/Linux-x86_64/595.71.05/README/powermanagement.html), [NVIDIA VA-API bridge](https://github.com/elFarto/nvidia-vaapi-driver#firefox).

## Before implementation/activation

- **Review an input refresh.** Mozilla's [release metadata](https://product-details.mozilla.org/1.0/firefox_versions.json) reports **155.0.1**, versus the pin's **154.0.1**. Reproducible does not mean current. Review the stable Nixpkgs update, browser/locker fixes, evaluation and build separately; no input was updated during this research. Do not move to development snapshots merely for cosmetic features.
- **Establish local authentication.** `dev` currently has a locked Unix password. SSH authorization and passwordless sudo do not give a graphical greeter, locker or polkit agent a usable password. Choose and declare an appropriate credential/secret mechanism before enabling a usable local login/lock workflow. No invented password, plaintext secret in the Nix store, empty-password workaround or silent autologin.
- **Keep the implementation flat:** shared desktop integration, native `hyprland.lua`, and opt-in NVIDIA settings, with each real machine retaining its own hardware/boot module. No deep host/profile framework and no Neovim changes.

## What was validated

Non-activating evaluations of candidate module compositions passed NixOS and Home Manager assertions for both Mesa-default and opt-in NVIDIA settings. They verified Lua defaults, UWSM ownership, both automatically supplied portals, PAM/idle integration without duplicate idle units, bar lifecycle/logout settings, unchanged Neovim package/source, and the NVIDIA 595 kernel-notifier parameters. These were evaluation fixtures using the existing host as a base, **not bootable physical-host definitions or desktop builds**.

The EC2 host exposes only a simple framebuffer DRM device, with no render node. No actual Hyprland session, hardware acceleration, screen sharing, password unlock, hotplug or suspend/resume was tested. Those checks must be run on the target machines, including wrong/correct-password behavior, locker-crash behavior, monitor changes while locked, and repeated suspend/resume with recovery access retained.
