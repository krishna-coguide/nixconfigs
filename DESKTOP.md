# Workstation design and visual audit

Reviewed 2026-09-06 UTC on the physical laptop and against the pinned upstream sources. JaKooLit is a **functional reference, not the visual template**. The goal is an informative, polished development workstation—not a sparse desktop and not a collection of theme selectors.

## Design

- Dark **One Ring** wallpaper, charcoal surfaces, parchment text and restrained old-gold accents. Terminal ANSI colors remain distinct; Neovim's theme and configuration are unchanged.
- One continuous top bar: launcher/workspaces/help and active-window context on the left, date/time in the center, media, CPU/RAM/temperature, notification count, privacy and laptop status on the right. Details and actions are available without filling the bar with permanent buttons.
- The bar's quick-settings panel owns audio, microphone, brightness, network/VPN, Bluetooth, power profiles and idle inhibition. Its **Actions** and **Health** buttons open the action palette and real system/update diagnostics.
- SwayNC owns notification history, actions, DND and media—not a duplicate hardware settings dashboard.
- Anyrun is the application/calculator launcher; Fuzzel provides consistent searchable action, clipboard, window and help pickers. Help is read from live described bindings and never executes a selected shortcut.
- Flat NixOS modules, Home Manager files, native Hyprland Lua, standard systemd services and small packaged helpers. No copied dotfile framework, downloaded login scripts, dynamic theme generators or additional recovery framework.

The laptop is **Intel Lunar Lake / Arc 130V–140V**, using `xe`, with a **1920×1200 internal panel now at 133⅓%** (1440×900 logical pixels; reduced from the original 150% audit at the user's request). The CPU temperature source is configured on this host, not guessed for every machine. No NVIDIA configuration, driver replacement, DNS change or storage migration is part of this work.

## What the audit repaired

1. **Session ownership:** the original SDDM selection started plain Hyprland without `graphical-session.target`; the configured bar, wallpaper, locker and polkit services consequently did not start. SDDM now offers only **Hyprland (uwsm-managed)**. Plasma and the `kbot` account are removed as requested; `/home/kbot` remains intact.
2. **Physical updates:** the laptop previously excluded the updater, whose script selected the EC2 host. Host selection is now explicit. Both hosts now share dev-owned checkouts and the same updater, staging checked generations for the next boot without logging out the user or rebooting.
3. **Shared styling:** native CSS and Lua are rendered from `colors.nix`, rather than keeping several unrelated palettes.
4. **Launcher geometry:** upstream gives the row, boxes, image and labels the same `.match` class. Applying padding to that class multiplied row height. Padding now applies only to `row.match`; application descriptions are hidden, results are bounded, and calculator results remain readable. A session-owned Anyrun daemon supports calculator clipboard output.
5. **Actual visual sizing:** screenshots led to a shorter/wider action picker, shorter help, smaller notification drawer, consistent borders, and removal of the thick upstream notification-focus background. Bar information was restored after an overly sparse iteration; information density is intentional.
6. **Duplicate/broken controls:** an unconfigured SwayNC backlight widget was present but uninitialized. Hardware controls now live in ashell's working native panel, not in both panels.
7. **Clipboard/lock behavior:** history is session-local; a clipboard write cannot race past the lock wipe, and a failed wipe cannot prevent the screen from locking. OSD notifications are transient and replace only other OSD messages, not screenshot/error notifications.
8. **Toolkit and apps:** the expanded toolset is declarative. Element is the official pinned Nightly, with its matching Electron/native modules and libsecret storage. Thunar, archives, image/video viewers and MIME defaults complement Yazi.

## Useful workflows

The authoritative full list is **Super-H** or **Super-Shift-K**, also available through the bar's `?` button.

| Capability | Entry point / implementation |
| --- | --- |
| Apps and calculator | **Super-D**, bar launcher; Anyrun applications/Rink |
| Files | **Super-E** Thunar; **Super-Ctrl-E** Yazi in Kitty |
| Window overview | **Super-A**, **Super-Ctrl-S**; workspace-labelled picker, validated addresses |
| Window operations | Super-arrows focus; Ctrl modifier moves, Alt swaps, Shift resizes; Super-G groups; Super-Ctrl-Tab changes group tab |
| Floating/fullscreen | **Super-Space** floating; **Super-Shift-F** fullscreen; **Super-Ctrl-F** maximize |
| Workspaces | Super-1…0; Shift moves and follows, Ctrl moves silently; Super-Tab cycles |
| Scratch/drop-down terminal | **Super-U** scratchpad; **Super-Shift-U** move to it; **Super-Shift-Enter** persistent drop-down terminal |
| Actions / quick settings | **Super-Shift-E** action palette; right side of bar opens hardware controls |
| Notifications / DND | **Super-Shift-N** history; **Super-Ctrl-N** DND; bell/count in bar |
| Clipboard | **Super-Alt-V**; text/images, delete, clear and pause/resume from Actions |
| Screenshots | Print menu; Super-Print output; Super-Shift-Print region; Alt-Print window; Ctrl variants delay 5/10 seconds; Super-Shift-S annotation |
| Recording | **Super-Alt-R**; region/output, no audio by default, explicit desktop-audio option; **REC** bar control stops recording |
| Capture feedback/privacy | Screenshot copy/save notification; recording owns a notification inhibitor without overwriting DND preferences; bar privacy indicators |
| Media/OSD | MPRIS bar module and media keys; volume/mic/brightness/keyboard-backlight keys have replacing feedback |
| Night light | **Super-N**; 4200 K from 21:00, identity from 07:00; manual toggle |
| Laptop controls | Power profile, airplane mode and temporary display scaling in Actions; Super-Alt-T touchpad; low/critical battery alerts |
| Emoji / color / search | Super-Alt-E emoji; color picker in Actions; Super-S URL-encoded web search |
| Session | Ctrl-Alt-L lock; Ctrl-Alt-P power menu; destructive menu actions require confirmation |
| Health | Bar settings → Health, Actions → System/update health, or `desktop health`; real units, journal and running/booted/selected generation |

Clipboard data lives in `$XDG_RUNTIME_DIR/workstation`, with a 200-item limit and private permissions. It is cleared on lock and service/session exit. Sources which label sensitive clipboard content are excluded; **universal password detection is not promised**. Pause history when appropriate.

Screenshots go to the XDG Pictures directory under `Screenshots`; recordings go to XDG Videos under `Recordings`. Region cancellation produces no empty capture. Recording has no microphone option enabled by default; the audio choice explicitly captures the output's monitor source. Recording suppression does not claim to detect every browser/portal screenshare.

## Visual and interaction checks

Native screenshots are kept locally under `~/.cache/desktop-audit/resume/`, **not committed**. They include the real 150% bar/wallpaper, application search, calculator, help, actions, notification drawer, quick settings and Element Nightly startup. Earlier iterations are retained for comparison; filenames alone are not proof that a check passed.

The native audit caught real issues that configuration evaluation did not: nested launcher padding, overly tall pickers, the notification focus slab and an uninitialized duplicate brightness control. The quick-settings screenshot confirms that the actual panel contains the audio/mic/brightness sliders, network/Bluetooth, idle inhibition, power profile, Actions and Health controls.

`desktop-test.py` exercises the disposable graphical VM using the same SDDM/UWSM workstation module as the laptop: session ownership, fonts, real PipeWire nodes, launcher geometry at 100%/150%, clipboard picker, recording container and no-audio default, notification ownership/inhibition, described help, and real wrong/correct-password PAM locking. Test credentials never reach the host. `desktop-actions-test.py` covers cancellation, untrusted input, byte-preserving clipboard behavior, lock failure handling, display timeout restoration and recording-inhibitor cleanup.

**Completed validation (2026-09-06):** flake evaluation, Nix formatting, generated Hyprland configuration, physical/AWS/shared-policy assertions, 125 CLI executable smoke checks, 14 desktop-action tests, 23 updater regressions, 22 manual-switch regressions (including lock retention through sudo), both host system builds, and the full SDDM/UWSM graphical/PAM/clipboard/recording VM check all passed on the refreshed inputs. Native clipboard, recording and rootless Podman checks passed too. The 150% six-result launcher and help screenshots were inspected visually; the transparent launcher click-catcher's IPC dimensions are not mistaken for the visible palette bounds.

**Account/hardware boundaries:**

- Element Nightly launches with libsecret enforced. The live audit reached the encryption warning because no unlocked/configured Secret Service vault was available. The insecure fallback was **not selected**. Open/configure KeePassXC's Secret Service group before signing in; account/vault setup remains the user's responsibility.
- Bluetooth pairing, real suspend/resume, external-monitor hotplug and interactive browser portal sharing require their respective hardware/account interaction. Package and VM tests are not substitutes.
- Temporary display scaling preserves output mode, position and rotation and reverts on timeout/cancel. Specific dock/mirror profiles are not invented without attached displays.

## Wallpaper provenance

[Wallhaven 01e5v4](https://wallhaven.cc/w/01e5v4), a dark One Ring inscription, **1920×1200**. Wallhaven lists uploader **ulairi88**, not a verified original artist, and provides no redistribution license. No artist attribution or open license is invented.

`wallpaper.nix` fetches immutable bytes:

```text
https://w.wallhaven.cc/full/01/wallhaven-01e5v4.jpg
sha256-3jkKzJ0q4MTlHygwUs3SuSiUIjUjkiTqSaM+q8EL/oc=
```

No wallpaper service is contacted at login. `wallpaper.svg` remains the original locally authored alternative. Existing generations retain the fetched image if the source later disappears.

## Reference, not imitation

Reviewed [JaKooLit/Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots), its [keybindings](https://github.com/JaKooLit/Hyprland-Dots/blob/main/config/hypr/configs/Keybinds.conf), [scripts](https://github.com/JaKooLit/Hyprland-Dots/tree/main/config/hypr/scripts), Waybar modules and SwayNC configuration, plus the announced successor [LinuxBeginnings/Hyprland-Dots](https://github.com/LinuxBeginnings/Hyprland-Dots). Familiar general shortcuts are retained without copying the installers, mutable `.conf` edits, presentation style or duplicate ownership.

**Excluded deliberately:** animation/theme/bar-layout selectors, online radio/weather/location services, live wallpaper effects, opacity/layout preset collections, speculative GPU/game-mode tuning and broad process-killing refresh scripts. Alt-Tab/window search supplies a useful overview without a second desktop shell for thumbnails.

Implementation references: [Hyprland 0.55 Lua example](https://github.com/hyprwm/Hyprland/blob/v0.55.4/example/hyprland.lua), installed Lua API stubs, [ashell](https://github.com/MalpenZibo/ashell), [Anyrun](https://github.com/anyrun-org/anyrun), [Fuzzel](https://codeberg.org/dnkl/fuzzel), [SwayNC](https://github.com/ErikReider/SwayNotificationCenter), [cliphist](https://github.com/sentriz/cliphist), [UWSM](https://github.com/Vladimir-csp/uwsm), and the locked package/module sources.
