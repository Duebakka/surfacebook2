# Surface Book 2 — omarchy plugin

An [omarchy](https://omarchy.org) bar widget and helper suite for the Microsoft
Surface Book 2: run the base keyboard's **eject** action from the desktop,
auto-switch to **tablet mode** when you detach the clipboard — the display
**follows how you hold it** (portrait or landscape, via the clipboard's HID
accelerometer), a custom **split on-screen keyboard** (two-thumb layout,
injected via ydotool) raises so the detached clipboard stays typeable — and
**toggle the touchscreen** while attached. A
**rotation lock** in the widget freezes the orientation until you switch it
back on.

Built on linux-surface's in-kernel SAM driver and
[surface-dtx-daemon](https://github.com/linux-surface/surface-dtx-daemon),
with the native omarchy shell as the UI host.

```
┌──────────────┬──────────────────────────────┐
│  💻 Laptop   │  __('is not printed; glyph ──┘
│  ▲          │  .')  laptop / tablet pill     │
└──────────────┴──────────────────────────────┘
```

## What it does

| Widget pill | Panel                             | Keybind IPC                     |
| ----------- | --------------------------------- | ------------------------------- |
| laptop / tablet glyph + status tooltip | clipboard mode, latch, base state | `eject`, `touchToggle`, `toggle` |
| left click  | opens the panel                    | `keyboardToggle`                |
| right click | quick-eject the base               | `keyboardOn` / `keyboardOff`    |

### Detach-time hooks (root)

- **`router.sh`** — `surface-dtx-daemon` runs it for `detach`, `detach_abort`
  and `attach`; it dispatches scripts in `detach.d/` / `attach.d/` and keeps
  the optional "veto" (`exit 91` aborts the detach).
- **`00-stock`** — preserves the package's default detach.sh behavior
  (unmount USB disks) before the latch opens.
- **GPU** (`gpu.remove_on_detach=1`) — removes the NVIDIA PCI device right
  before detach and rescans on attach, instead of leaving
  `nvidia-580xx` bound to a device that has left the bus.
- **Touch inhibit** (`touch.inhibit_on_detach=1`) — kernel-inhibits
  direct-input (touch/digitizer) devices across the detach/attach instant.

## Requirements

- omarchy (Hyprland + Quickshell shell)
- linux-surface kernel with in-tree SAM drivers (`surface_dtx`, …)
- `surface-dtx-daemon` + `surface-dtx-userd` (both services running)
- `busctl`, `jq`, `hyprctl`, `ydotool` — required for the on-screen keyboard
  (`yay -S ydotool`; the install step enables a user unit for `ydotoold`)
- (recommended) `omarchy-toggle-input-device` — ships with omarchy

## Install

```sh
git clone https://github.com/duebakka/surfacebook2
cd surfacebook2
./bin/surfbookctl install
```

`install`:

1. copies the plugin to `~/.config/omarchy/plugins/dues.surfacebook2`
   (Quickshell hot-reloads it);
2. writes `~/.config/surfacebook/tablet.conf` (classic example defaults);
3. installs the root hooks behind a `pkexec`/`sudo` prompt:
   - `/usr/local/lib/surfacebook/{bin,system/hooks}` + `surfbookctl`,
     `surfbookd`, `surfbook-sys` symlinks in `/usr/local/bin`;
   - `/etc/surface-dtx/{detach,detach_abort,attach}.sh` wrappers (stock
     scripts preserved as `*.dist`), daemon conf backed up
     (`surface-dtx-daemon.conf.pkg-orig`) and relaxed once so
     `detach_abort` points at its own script;
   - restarts `surface-dtx-daemon`;
   - user units `surfacebook-watchdog.service` (tablet mode) and
     `surfacebook-ydotoold.service` (ydotool daemon for the on-screen keyboard)
     in `/usr/local/lib/systemd/user/`;
4. starts the watchdog (and enables `surfacebook-ydotoold.service`). The bar is
   on your next shell reload —
   **Settings → Bar & Popups → Widgets → Surface Book 2 Tablet & OSK**.

Under the hood: `surfbookd` (user service) polls `org.surface.dtx` over the
system bus and mirrors it to `$XDG_STATE_HOME/surfacebook/state.json`; the
panel actions talk to `surfbookctl`. Root is only needed for the detach hooks.

## Usage

```sh
surfbookctl status               # mode, latch, base, touch, rotation, keyboard, watchdog
surfbookctl eject                # software-eject the base
surfbookctl touch toggle         # touchscreen on/off (Hyprland device toggle)
surfbookctl rotation auto|locked # auto-rotate vs freeze orientation
surfbookctl rotation status      # current rotation mode
surfbookctl keyboard auto|on|off # on-screen keyboard: tablet-only, always, never
surfbookctl keyboard toggle      # flip auto on/off
surfbookctl keyboard status      # on/off (what the OSK will show now)
surfbookctl watchdog restart     # manage the tablet-mode service
surfbookctl uninstall            # reverse of install
```

### Auto-rotate & rotation lock

In tablet mode the display turns to match how you hold the clipboard: hold it
like a book and it goes to `transform_top` (portrait), turn it sideways and it
switches to `transform_left`/`transform_right` (landscape). The reading comes
from the clipboard's on-board HID accelerometer (`accel_3d`, an IIO device);
grip changes are debounced (`sensor_debounce` polls) before the display moves.

The **Auto rotate** toggle in the widget (or `surfbookctl rotation`) toggles
between:

- `auto` — the display follows the held orientation (default);
- `locked` — the transform freezes; re-attaching to the base still returns to
  laptop landscape. The lock persists for the session only.

### On-screen keyboard (tablet mode)

When the clipboard is detached (tablet mode) there is no physical keyboard, so
the plugin raises its own **split on-screen keyboard** — a two-thumb layout
(left/right halves mirrored toward the thumb edges) rendered as a Quickshell
overlay. Every key taps through **`ydotool`** (talking to `ydotoold`, a user
service the install step enables), so keystrokes land in whatever application
currently has focus. The overlay itself never takes keyboard focus — a
`WlrKeyboardFocus.None` layer surface — so `ydotool` injects into your editor,
terminal, or browser directly. This is why the plugin ships its own keyboard
instead of relying on an input-method based one like `wvkbd`: Hyprland gives
the input-method slot to `fcitx5` when it is installed, so `wvkbd` never
auto-shows there.

- **Layout**: letters page (with a latched **Shift** and a **SYM** key to
  switch to numbers/symbols) and a symbols page, plus a full-width bottom row
  (space, dismiss, enter). A dedicated **dismiss** key on the bottom row turns
  the keyboard off without leaving tablet mode.
- **Automatic**: in tablet mode with a detached base, the keyboard appears on
  its own (state mirrored to `$XDG_STATE_HOME/surfacebook/state.json` by
  `surfbookd`); re-attaching the base, or pressing dismiss, hides it. Controlled
  by `keyboard_mode` in `tablet.conf` (`auto` default, `on` to always show,
  `off` to never show).
- **Manual**: `surfbookctl keyboard toggle` (or the **On-screen keyboard**
  toggle on the widget panel, or the `SUPER+K`-style bind below) flips between
  auto and off at runtime; `surfbookctl keyboard on|off` forces it explicitly.
- **Summon/hide from the shell**: because the plugin declares the `overlay`
  entry point, `shell.summon dues.surfacebook2` opens the keyboard and
  `shell.hide` dismisses it — same as the panel toggle.

The `ydotool` input path needs `/dev/uinput` writable from your user session,
which `ydotoold` arranges via logind's `uaccess` ACL (`surfacebookctl install`
enables `surfacebook-ydotoold.service` so it comes back on login).

### Keybindings (optional)

```lua
bind = SUPER, E, exec, surfbookctl eject
bind = SUPER, T, exec, surfbookctl touch toggle
bind = SUPER, K, exec, surfbookctl keyboard toggle
```

## Configuration

`/etc/surfacebook/tablet.conf` (system) and
`~/.config/surfacebook/tablet.conf` (user overrides):

```ini
rotation_mode=auto        # auto | locked (see "Auto-rotate & rotation lock")
autorotate=1              # legacy: 0 disables rotation entirely
keyboard_mode=auto        # auto | on | off (see "On-screen keyboard")
monitor=eDP-1
transform_laptop=0
transform_tablet=1        # SB2 portrait
transform_top=0           # upright -> laptop landscape
transform_bottom=2
transform_left=1          # held sideways -> landscape
transform_right=3
sensor_threshold=5.0      # m/s^2 floor before an axis counts as "down"
sensor_debounce=2         # polls a new orientation must hold before applying
poll_interval=2

gpu.remove_on_detach=0
gpu.slot=0000:01:00.0

touch.inhibit_on_detach=0
```

> **Note on touch.** The Surface Book 2's display touch/pen runs on Intel IPTS
> — an out-of-tree driver (`ipts` kernel module) not shipped by omarchy's
> kernel. Install the module and run it in event mode, and the clipboard
> screen exposes a real touchscreen (Hyprland-registered), which
> `surfbookctl touch toggle` drives through `omarchy-toggle-input-device`
> (Hyprland device + persisted state + OSD), with a kernel
> `inhibited`-sysfs fallback for digitizers Hyprland can't see. Turning touch
> **off** while the base is detached is refused (and the panel toggle greys
> out) — a detached clipboard has no physical keyboard, so the touchscreen is
> its only input.
> See "IPTS touchscreen" below.

### IPTS touchscreen (Surface Book 2)

The omarchy kernel ships no IPTS driver. The clipboard's panel has an Intel
iTouch controller (`00:16.4`), exposed as a MEI client. The `ipts` kernel
module can drive it standalone in **event mode** — the controller's own
firmware does the touch processing and the kernel exposes a real
`IPTS 045E:0021 Touchscreen` input device. Install just the module:

```sh
# 1. kernel module (DKMS), built against the running omarchy kernel.
#    Pinned to a known-good commit and verified before any privileged
#    dkms step, so a later upstream change (or a compromised upstream
#    repo) can't silently alter what root loads into the kernel:
ipts_commit=3b88a45360b4fdab85e2d4389fb4812f5867c1b7
git clone https://github.com/linux-surface/intel-precise-touch /tmp/ipts
git -C /tmp/ipts checkout --detach "$ipts_commit" || exit 1
[ "$(git -C /tmp/ipts rev-parse HEAD)" = "$ipts_commit" ] \
  || { echo "ipts checkout verification failed; aborting" >&2; exit 1; }
sudo dkms add /tmp/ipts
sudo dkms install --force ipts/1.0.0

# 2. autoload at boot:
echo ipts | sudo tee /etc/modules-load.d/ipts.conf

# 3. do NOT let iptsd touch it (see below — it poisons the sensor):
sudo systemctl mask iptsd@.service
```

Do **not** install/run the `iptsd` userspace daemon. On this SB2 it fails the
protocol-mode handover (`Failed to set memory window: -11`, then
`ENODEV`/`EAGAIN` on the data ioctl) and leaves the ME controller in a state
where the touch sensor won't respond until a full reboot. With the daemon
masked, event mode survives a reboot and touch just works as a normal evdev
device (`event10`, Hyprland-registered). If `iptsd@.service` is unmasked, a
reboot is required to recover the sensor.

## Troubleshooting

- **Logs**: hooks → `/var/log/surfacebook-hooks.log`; watchdog →
  `~/.local/state/surfacebook/watchdog.log`.
- **Eject does nothing**: `systemctl status surface-dtx-daemon`; the D-Bus
  API surface must respond on `org.surface.dtx`. Check with
  `busctl --system get-property org.surface.dtx /org/surface/dtx org.surface.dtx DeviceMode`.
- **No bar widget**: Quickshell may need a full shell restart
  (`Ctrl+Alt+Z`-ish user-initiated; log into the desktop again).
- **Screen stuck in portrait after reattaching**: the watchdog drives rotation
  through `hl.monitor({ output, mode, position, scale, transform })`. Since
  Hyprland 0.5x silently ignores a transform-only rule, `surfbookd` always
  passes the full monitor rule (and verifies/re-applies once). If your copy is
  older, `surfbookctl watchdog restart` after updating, then re-detach.

## Publish to the omarchy marketplace

1. Push this repo to GitHub (public).
2. `manifest.json` already declares `schemaVersion: 1`,
   `id: dues.surfacebook2`, `kinds: ["bar-widget", "overlay"]` and the
   `barWidget.entryPoints` (plus `overlay.entryPoints` for the on-screen
   keyboard).
3. Visit <https://plugins.omarchy.org/publish>, point it at the repo, and
   submit. The registry picks up the manifest from the repo root.

## License

MIT (see `LICENSE`). Not affiliated with Microsoft or the linux-surface
project.