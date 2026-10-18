-- Native Hyprland 0.55 configuration, deployed by Home Manager.
-- @color@ tokens are rendered from colors.nix at build time.
-- Services belong to UWSM/systemd, never a second exec-once process tree.
local function rgb(hex) return "rgb(" .. hex:sub(2) .. ")" end
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
hl.config({
    general = {
        gaps_in = 4, gaps_out = 8, border_size = 2,
        layout = "dwindle", resize_on_border = true, allow_tearing = false,
        col = {
            active_border = { colors = { rgb("@accent@"), rgb("@green@") }, angle = 45 },
            inactive_border = rgb("@border@"),
        },
    },
    decoration = {
        rounding = 6,
        active_opacity = 1.0, inactive_opacity = 1.0,
        shadow = { enabled = true, range = 16, render_power = 3, color = 0x55000000 },
        blur = { enabled = false },
    },
    animations = { enabled = true },
    dwindle = { preserve_split = true },
    input = {
        kb_layout = "us", follow_mouse = 1,
        repeat_rate = 35, repeat_delay = 250,
        touchpad = { natural_scroll = true, tap_to_click = true },
    },
    misc = { disable_hyprland_logo = true, force_default_wallpaper = 0 },
    ecosystem = { no_update_news = true },
})
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.curve("settle", { type = "bezier", points = { { 0.2, 0.85 }, { 0.25, 1 } } })
hl.animation({ leaf = "global", enabled = true, speed = 2.5, bezier = "settle" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.5, bezier = "settle", style = "popin 97%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.5, bezier = "settle", style = "popin 97%" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.5, bezier = "settle", style = "slidefade 12%" })
hl.animation({ leaf = "layers", enabled = true, speed = 2, bezier = "settle", style = "fade" })
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Every binding is discoverable through hyprctl -j binds / desktop-help.
local function bind(keys, action, description, options)
    options = options or {}
    options.description = description
    hl.bind(keys, action, options)
end
local function app(command) return hl.dsp.exec_cmd("uwsm app -- " .. command) end
bind("SUPER + Return", app("kitty"), "Apps · Terminal")
bind("SUPER + D", app("anyrun"), "Apps · Search applications / calculator")
bind("SUPER + A", app("desktop windows"), "Windows · Overview / search")
bind("SUPER + CTRL + S", app("desktop windows"), "Windows · Search all windows")
bind("SUPER + E", app("thunar"), "Apps · Graphical file manager")
bind("SUPER + CTRL + E", app("kitty --class files -e yazi"), "Apps · Yazi terminal file manager")
bind("SUPER + B", app("firefox-esr"), "Apps · Browser")
bind("SUPER + ALT + P", app("keepassxc"), "Apps · Password vault")
bind("SUPER + P", hl.dsp.window.pseudo(), "Windows · Toggle pseudotiling")
bind("SUPER + H", app("desktop-help"), "Help · Search all keyboard shortcuts")
bind("SUPER + SHIFT + K", app("desktop-help"), "Help · Search all keyboard shortcuts")
bind("CTRL + ALT + L", hl.dsp.exec_cmd("loginctl lock-session"), "Session · Lock screen")
bind("SUPER + Escape", hl.dsp.exec_cmd("loginctl lock-session"), "Session · Lock screen (alias)")
bind("CTRL + ALT + P", app("desktop power"), "Session · Power / logout menu")
bind("SUPER + SHIFT + E", app("desktop menu"), "Desktop · Quick settings / actions")
bind("SUPER + ALT + V", app("desktop clipboard"), "Clipboard · History")
bind("SUPER + ALT + E", app("desktop emoji"), "Clipboard · Emoji picker")
bind("SUPER + ALT + C", app("anyrun"), "Apps · Calculator (enter an expression)")
bind("SUPER + S", app("desktop search"), "Apps · Search web")
bind("SUPER + SHIFT + Return", app("desktop scratch"), "Windows · Drop-down terminal")
bind("SUPER + ALT + R", app("desktop record"), "Capture · Start / stop recording")
bind("SUPER + ALT + T", app("desktop touchpad"), "Input · Toggle touchpad")
-- The Copilot key sends Super+Shift+XF86Assistant as one chord.
bind("SUPER + SHIFT + XF86Assistant", hl.dsp.exec_cmd("voxtype record toggle"), "Input · Dictation start / stop")
bind("SUPER + Q", hl.dsp.window.close(), "Windows · Close active window")
bind("SUPER + Space", hl.dsp.window.float({ action = "toggle" }), "Windows · Toggle floating")
bind("SUPER + F", hl.dsp.window.fullscreen(), "Windows · Toggle fullscreen (alias)")
bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen(), "Windows · Toggle fullscreen")
bind("SUPER + CTRL + F", hl.dsp.window.fullscreen({mode = "maximized"}), "Windows · Toggle maximize")
bind("SUPER + SHIFT + I", hl.dsp.layout("togglesplit"), "Windows · Toggle split direction")
bind("SUPER + N", app("desktop night"), "Display · Toggle night light")
bind("SUPER + SHIFT + N", app("desktop notifications"), "Notifications · Open history / controls")
bind("SUPER + CTRL + N", app("desktop dnd"), "Notifications · Toggle do not disturb")
bind("ALT + Tab", hl.dsp.window.cycle_next(), "Windows · Cycle forward")
bind("ALT + SHIFT + Tab", hl.dsp.window.cycle_next({next = false}), "Windows · Cycle backward")
bind("SUPER + G", hl.dsp.group.toggle(), "Windows · Toggle tabbed group")
bind("SUPER + CTRL + Tab", hl.dsp.group.next(), "Windows · Next group tab")
bind("Print", app("desktop screenshot-menu"), "Capture · Screenshot menu")
bind("SUPER + Print", app("desktop screenshot output"), "Capture · Current display")
bind("SUPER + SHIFT + Print", app("desktop screenshot area"), "Capture · Region")
bind("SUPER + CTRL + Print", app("desktop screenshot output --delay5"), "Capture · Display after 5 seconds")
bind("SUPER + CTRL + SHIFT + Print", app("desktop screenshot output --delay10"), "Capture · Display after 10 seconds")
bind("ALT + Print", app("desktop screenshot window"), "Capture · Active window")
bind("SUPER + SHIFT + S", app("desktop-screenshot"), "Capture · Region and annotation")

for _, direction in ipairs({ "left", "right", "up", "down" }) do
    bind("SUPER + " .. direction, hl.dsp.focus({ direction = direction }), "Windows · Focus " .. direction)
    bind("SUPER + CTRL + " .. direction, hl.dsp.window.move({ direction = direction }), "Windows · Move " .. direction)
    bind("SUPER + ALT + " .. direction, hl.dsp.window.swap({ direction = direction }), "Windows · Swap " .. direction)
    local dx = direction == "left" and -50 or direction == "right" and 50 or 0
    local dy = direction == "up" and -50 or direction == "down" and 50 or 0
    bind("SUPER + SHIFT + " .. direction, hl.dsp.window.resize({ x = dx, y = dy, relative = true }), "Windows · Resize " .. direction, {repeating = true})
end
for i = 1, 10 do
    local key = i % 10
    bind("SUPER + " .. key, hl.dsp.focus({ workspace = i }), "Workspaces · Focus " .. i)
    bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = true }), "Workspaces · Move and follow to " .. i)
    bind("SUPER + CTRL + " .. key, hl.dsp.window.move({ workspace = i, follow = false }), "Workspaces · Move silently to " .. i)
end
bind("SUPER + U", hl.dsp.workspace.toggle_special("scratch"), "Workspaces · Toggle scratchpad")
bind("SUPER + SHIFT + U", hl.dsp.window.move({ workspace = "special:scratch" }), "Workspaces · Move window to scratchpad")
bind("SUPER + Tab", hl.dsp.focus({workspace = "m+1"}), "Workspaces · Next on this monitor")
bind("SUPER + SHIFT + Tab", hl.dsp.focus({workspace = "m-1"}), "Workspaces · Previous on this monitor")
for i, direction in ipairs({"left", "right", "up", "down"}) do
    bind("SUPER + CTRL + F" .. (8 + i), hl.dsp.workspace.move({monitor = direction}), "Monitors · Move workspace " .. direction)
end
bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "Workspaces · Next occupied workspace")
bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }), "Workspaces · Previous occupied workspace")
bind("SUPER + mouse:272", hl.dsp.window.drag(), "Windows · Drag with left mouse", { mouse = true })
bind("SUPER + mouse:273", hl.dsp.window.resize(), "Windows · Resize with right mouse", { mouse = true })

bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("desktop osd volume up"), "Media · Volume up", { locked = true, repeating = true })
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("desktop osd volume down"), "Media · Volume down", { locked = true, repeating = true })
bind("XF86AudioMute", hl.dsp.exec_cmd("desktop osd volume mute"), "Media · Toggle speaker mute", { locked = true })
bind("XF86AudioMicMute", hl.dsp.exec_cmd("desktop osd microphone mute"), "Media · Toggle microphone mute", { locked = true })
bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("desktop osd brightness up"), "Display · Brightness up", { locked = true, repeating = true })
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("desktop osd brightness down"), "Display · Brightness down", { locked = true, repeating = true })
bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), "Media · Play / pause", { locked = true })
bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), "Media · Next track", { locked = true })
bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), "Media · Previous track", { locked = true })

bind("XF86KbdBrightnessUp", hl.dsp.exec_cmd("desktop osd keyboard up"), "Input · Keyboard backlight up", {locked = true, repeating = true})
bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("desktop osd keyboard down"), "Input · Keyboard backlight down", {locked = true, repeating = true})
bind("XF86RFKill", app("desktop airplane"), "Network · Toggle airplane mode")
bind("XF86Sleep", hl.dsp.exec_cmd("systemctl suspend"), "Session · Suspend")

hl.window_rule({name = "dropterminal", match = {class = "^dropterminal$"}, workspace = "special:terminal", float = true, center = true})
hl.window_rule({ name = "ignore-maximize", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({
    name = "fix-xwayland-drag", match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})
