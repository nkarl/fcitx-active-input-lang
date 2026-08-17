# Fcitx Input Method Indicator

An Omarchy Quattro bar widget that displays the active Fcitx 5 input method and
lets you prioritize, configure, and switch between methods in the active Fcitx
group.

## Requirements

- Omarchy Quattro
- An x86-64 system
- Fcitx 5, running in the graphical session
- `systemd-libs`, required by the included `fcitx-state-monitor` helper
- At least one input method configured in the active Fcitx group

Install the runtime dependencies from the Arch repositories:

```sh
sudo pacman -S fcitx5 fcitx5-gtk fcitx5-qt systemd-libs
```

Install any input engines you want to use separately, then add them to the
active Fcitx group. For example, Vietnamese Lotus is available from the AUR:

```sh
yay -S fcitx5-lotus-bin
```

## Install

```sh
omarchy plugin add https://github.com/nkarl/fcitx-active-input-lang.git --enable
```

## Usage

- Left-click the bar label to switch to the next prioritized input method.
- Right-click the label to open the configuration panel.
- In the panel, promote a method with `↑`, remove a non-active method with `−`,
  edit its one-to-three-character label, or add another method from the active
  Fcitx group.

The active method is always first. Changes are saved to the widget entry in
`~/.config/omarchy/shell.json`.

## Configure

Configure input methods and groups outside the plugin with Fcitx tools. The
optional graphical configuration tool is available with:

```sh
sudo pacman -S fcitx5-configtool
```

After changing the active Fcitx group, reopen the plugin panel to refresh the
available methods.

## Remove

```sh
omarchy plugin remove nkarl.fcitx-active-input-lang
```

## License

MIT
