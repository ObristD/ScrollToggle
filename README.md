# ScrollToggle

A tiny macOS menu bar app that switches the system scroll direction
("Natural" vs. "Standard") for mouse and trackpad with one click.

- **Left-click** the icon: switch direction immediately (no restart, no logout).
- **Right-click**: menu with the current state, "Launch at Login" and Quit.
- Icon: hand = Natural scrolling, mouse = Standard scrolling.
- Stays in sync if you change the setting in System Settings.

It calls the same function System Settings uses (`setSwipeScrollDirection`
in the private PreferencePanesSupport framework), so the change applies
system-wide right away.

## Build

```bash
./build.sh
```

Produces `ScrollToggle.app` next to the script. Requires Xcode Command Line Tools.

## Install

Move `ScrollToggle.app` to `/Applications` (or `~/Applications` on a non-admin account), open it once, then enable
"Launch at Login" from its right-click menu. Launch at Login only works
reliably when the app lives in a stable location such as `/Applications`.

From the terminal you can also run `ScrollToggle.app/Contents/MacOS/ScrollToggle --login-on`
or `--login-off` to register or unregister the login item without opening the menu.
