<div align="center"><p align="center"><img src="https://gnos.in/img/shot/features/theme_0.png" width="600" title="GNOS"></p></div>

# GNOS Theme

Minimalist flat dark theme for:

- Gnome Shell 3.20 - 3.28
- GTK 2 + 3
- GtkSourceView (Meld)
- Kvantum (VirtualBox)
- Sublime Text
- Audacity

Also includes some GNOS branding assets.

## Install

Uncompress the latest release to `~/.local/share/themes`.

## Build

GNOS [installer](https://github.com/gnos-project/gnos-gnowledge) is required to install dependencies & build the theme:

```
sudo gnowledge -a theme.bash Internal BuildTheme "Gnos-theme"
```

## Customizing

To build with custom colors you need patch these variables in installer's `InitAdditional` function:

```bash
THEME_COLOR_FOREGD_RGB="192,192,192"
THEME_COLOR_BACKGD_RGB="24,22,20"
THEME_COLOR_WINDOW_RGB="36,34,32"
THEME_COLOR_OBJECT_RGB="48,46,44"
THEME_COLOR_SELECT_RGB="23,77,141"
THEME_COLOR_HOTHOT_RGB="234,117,0"
THEME_COLOR_MANAGE_RGB="183,58,48"
THEME_COLOR_OKOKOK_RGB="47,134,70"
```

## Credits

GNOS theme is a hacky automated patch of [Arc Dark theme](https://horst3180/arc-theme).
