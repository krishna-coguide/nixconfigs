-- Native Hyprland 0.55 configuration, deployed by Home Manager.
-- Services belong to UWSM/systemd, never a second exec-once process tree.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

hl.config({
    general = {
        gaps_in = 6, gaps_out = 12, border_size = 2,
        layout = "dwindle", resize_on_border = true, allow_tearing = false,
        col = {
            active_border = { colors = { "rgb(78a9ff)", "rgb(be95ff)" }, angle = 45 },
            inactive_border = "rgb(393939)",
        },
    },
    decoration = {
        rounding = 12,
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

local function app(command) return hl.dsp.exec_cmd("uwsm app -- " .. command) end
hl.bind("SUPER + Return", app("kitty"))
hl.bind("SUPER + Space", app("anyrun"))
hl.bind("SUPER + E", app("kitty --class files -e yazi"))
hl.bind("SUPER + B", app("firefox-esr"))
hl.bind("SUPER + P", app("keepassxc"))
hl.bind("SUPER + Escape", hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + F", hl.dsp.window.fullscreen())
hl.bind("SUPER + J", hl.dsp.layout("togglesplit"))
hl.bind("SUPER + N", hl.dsp.exec_cmd("makoctl dismiss"))
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd("makoctl restore"))
hl.bind("Print", hl.dsp.exec_cmd("desktop-screenshot"))

for _, direction in ipairs({ "left", "right", "up", "down" }) do
    hl.bind("SUPER + " .. direction, hl.dsp.focus({ direction = direction }))
    hl.bind("SUPER + SHIFT + " .. direction, hl.dsp.window.move({ direction = direction }))
end
for i = 1, 10 do
    local key = i % 10
    hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("scratch"))
hl.bind("SUPER + SHIFT + S", hl.dsp.window.move({ workspace = "special:scratch" }))
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +5%"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl --min-value=1 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.window_rule({ name = "ignore-maximize", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({
    name = "fix-xwayland-drag", match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})
