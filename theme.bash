
# TIP: Build, pack & copy
# time sudo gnos -a theme.bash Internal BuildTheme Gnos-theme
# zip -r Gnos-theme.zip Gnos-theme ; zip -r Gnos-theme.src.zip Gnos-theme.src
# cp  Gnos-theme.zip Gnos-theme.src.zip /data/code/gnos/gnos-theme
# scp Gnos-theme.zip Gnos-theme.src.zip mbp:/data/code/gnos/gnos-theme

BuildTheme () # $1:NAME
{
    local dst=$1
    [[ -z "$1" ]] && dst=$THEME_GS

    [[ -e "$dst.src" || -e "$dst" ]] && sys::Die "Theme exists already"

    local uninstall uninstallNvm

    SetupArcThemeSources "$dst.src"
    PatchArcThemeSources "$dst.src"
    BuildPatchedArcTheme "$dst.src" "$dst"

    [[ -n "$uninstall" ]] && apt::RemovePackages $uninstall

    if [[ -n "$uninstallNvm" ]] ; then
        rm -rf \
            $HOME/.nvm \
            $HOME/.bashrc.d/nvm \
            $HOME/.config/configstore/update-notifier-npm.json \
            $HOME/.npm
    fi
}


SetupArcThemeSources () # $1:NAME
{
    # DEPS

    apt::Update

    # nvm
    if [[ ! -d "$HOME/.nvm" ]] ; then
        uninstallNvm=1
        cli::Node
    fi

    # gulp
    if ! which gulp ; then
        npm::Install gulp #@3.9.1
    fi
    # npm::Install gulp
    # BUG: pulls 4.0

    # convert
    if ! which convert ; then
        uninstall="$uninstall imagemagick"
        apt::AddPackages imagemagick
    fi

    # inkscape
    if ! which inkscape ; then
        uninstall="$uninstall inkscape"
        apt::AddPackages inkscape
    fi

    # optipng
    if ! which optipng ; then
        uninstall="$uninstall optipng"
        apt::AddPackages optipng
    fi


    ## Downlad Theme: ARC

    local themeName=$1
    [[ -z "$1" ]] && themeName=$PRODUCT_NAME
    [[ -e "$1" ]] && sys::Die "$1 already exists, remove it first"

    local tempzip=$( mktemp )
    net::Download \
        "https://github.com/horst3180/arc-theme/archive/20160605.zip" \
        $tempzip
    unzip $tempzip # TODO into temporary dir
    sys::Chk
    rm -rf $tempzip
    mv arc-theme-20160605 "$themeName"
    sys::Chk


    local themePath=$(pwd)/$themeName


    ## Downlad Theme: arc-flatabulous
    net::Download \
        "https://github.com/andreisergiu98/arc-flatabulous-theme/archive/master.zip" \
        $tempzip

    unzip $tempzip \
        "arc-flatabulous-theme-master/common/gtk-3.0/3.20/assets/titlebutton-*" \
        -d "$themePath"
    sys::Chk

    # Darken backdrop icons
    local tmppng=$( mktemp )
    pushd "$themePath/arc-flatabulous-theme-master/common/gtk-3.0/3.20/assets/"
    for file in titlebutton-*backdrop*.png ; do
        convert "$file" -fill black -colorize 70% "$tmppng"
        sys::Chk
        cp "$tmppng" "$file"
        sys::Chk
    done
    popd
    rm "$tmppng"

    chown -hR 1000:1000 "$themePath"


# UNUSED SINCE GULP 4 UPDATE
#     # Fix old unavailable node-sass version
#     sys::Write <<'EOF' "$themePath/package.json"
# {
#   "devDependencies": {
#     "gulp": "3.9.1",
#     "gulp-sass": "*",
#     "gulp-rename": "*"
#   }
# }
# EOF


# WORKAROUND SINCE GULP 4 UPDATE
    sys::Write <<'EOF' "$themePath/package.json"
{
  "devDependencies": {
    "gulp": "4",
    "gulp-rename": "*",
    "gulp-sass": "4",
    "node-sass": "4"
  },
  "dependencies": {
    "node-gyp": "4"
  }
}
EOF

# GULP 4 FORMAT UPDATE
    sys::PatchText <<'EOF' "$themePath/gulpfile.js"
@@ -17,4 +17,4 @@
         .pipe(gulp.dest('./'))
 });
 
-gulp.task('default', ['sass']);
+gulp.task('default', gulp.parallel('sass'));
EOF


    ## Init: GNOME

    # GS: remove some unused stuff
    pushd "$themePath/common/gnome-shell/3.20/"
    rm -rf \
        cinnamon metacity-1 unity xfce-notify-4.0 xfwm4 xfwm4-dark \
        gtk-3.0/3.1*/ gnome-shell/3.1*/
    popd

    # GS: gulp
    pushd "$themePath/common/gnome-shell/3.20/"
    npm::UserInstall
    popd

    # GTK: gulp
    pushd "$themePath/common/gtk-3.0/3.20/"
    npm::UserInstall
    popd

}





PatchArcThemeSources () # $1:SRC_PATH
{
    # ARGS
    [[ $# -ne 1 ]] && sys::Die "invalid arguments"
    local srcPath=$1

    # UNUSED FUNC
    SetupArcThemeSources::BackupFile () # $1:FILE
    {
        local bname=$( basename "$1" )
        local dname=$( dirname "$1" )
        local oname="$dname/_ORIG_$bname"
        [[ -e "$oname" ]] || cp "$1" "$oname"
    }

    # MAIN

    pushd "$srcPath"

    # PATCH GS: font, .modal-dialog, #panel, overview
    sys::PatchText <<'EOF' common/gnome-shell/3.20/sass/_common.scss
@@ -25,8 +25,8 @@
 //
 // Globals
 //
-$font-size: 9;
-$font-family: Futura Bk bt, Cantarell, Sans-Serif;
+$font-size: 12;
+$font-family: Sans;
 $_bubble_bg_color: opacify($osd_bg_color,0.25);
 $_bubble_fg_color: $osd_fg_color;
 $_bubble_borders_color: transparentize($osd_fg_color,0.8);
@@ -203,9 +203,8 @@

 .modal-dialog {
   color: $fg_color;
-  background-color: transparentize($bg_color, 1);
+  background-color: $bg_color;
   border: none;
-  border-image: url("#{$asset_path}/misc/modal.svg") 9 9 9 67;
   padding: 0 5px 6px 5px;

   .modal-dialog-content-box {
@@ -840,7 +839,6 @@
   background-gradient-direction: none;
   background-color: transparent;
   border-bottom-width: 0;
-  border-image: url('common-assets/panel/panel.svg') 1 1 1 1;

   // Fix dynamic top bar extension
   &.dynamic-top-bar-white-btn { border-image: none; }
@@ -852,8 +850,6 @@
     border-image: none;
   }

-  &:overview { border-image: url('common-assets/panel/panel-overview.svg') 1 1 1 1; }
-
   #panelLeft, #panelCenter { // spacing between activities<>app menu and such
     spacing: 8px;
   }
@@ -879,7 +875,8 @@
     -natural-hpadding: 10px;
     -minimum-hpadding: 6px;
     font-weight: bold;
-    color: $selected_fg_color;
+    font-size: 12pt;
+    color: $fg_color;
     transition-duration: 100ms;
     border-bottom-width: 1px;
     border-color: transparent;
@@ -893,7 +890,6 @@

     &:hover {
       color: $selected_fg_color;
-      background-color: transparentize(black, 0.83);
       border-bottom-width: 1px;
       border-color: transparent;
     }

@@ -1419,7 +1415,10 @@
 //
 // Overview
 //
-#overview { spacing: 24px; }
+#overview {
+  spacing: 24px;
+  background-color: $base_color;
+}

 .overview-controls { padding-bottom: 32px; }

EOF

    sys::Write --append <<EOF $(pwd)/common/gnome-shell/3.20/sass/_common.scss

.window-caption {
      background-color: rgba(0, 0, 0, 0);
}
.window-caption:hover {
  color: #FFFFFF;
  background-color: #$THEME_COLOR_SELECT_HEX;
}

.search-entry {
  border: 1px solid #$THEME_COLOR_SELECT_HEX;
  background-color: #$THEME_COLOR_SELECT_HEX;
}

.show-apps .overview-icon {
  background-color: transparent;
}

.show-apps:hover .overview-icon {
  background-color: #$THEME_COLOR_SELECT_HEX;
}

.app-well-app.app-folder > .overview-icon {
  background-color: transparent;
  border: none;
}

stage {
  font-family: "$THEME_FONT_SHORT_NAME";
}

#panel .panel-button:active, #panel .panel-button:overview, #panel .panel-button:focus, #panel .panel-button:checked {
    border-color: transparent;
}
EOF



    # Patch gtk3 colors: $header_border
    # SetupArcThemeSources::BackupFile common/gtk-3.0/3.20/sass/_colors.scss
    cp common/gtk-3.0/3.20/sass/_colors.scss common/gtk-3.0/3.20/sass/_colors.scss.ORIG
    sys::PatchText <<'EOF' common/gtk-3.0/3.20/sass/_colors.scss
@@ -36,7 +36,7 @@

 $header_bg_backdrop: if($darker == 'true' or $variant == 'dark', lighten($header_bg, 1.5%), lighten($header_bg, 3%));

-$header_border: if($variant == 'light' and $darker=='false', darken($header_bg, 7%), darken($header_bg, 4%));
+$header_border: if($variant == 'light' and $darker=='false', $header_bg, darken($header_bg, 4%));

 $header_fg: if($variant == 'light', saturate(transparentize($fg_color, 0.2), 10%), saturate(transparentize($fg_color, 0.2), 10%));
 $header_fg: if($darker == 'true', saturate(transparentize(#c0c0c0, 0.2), 10%), $header_fg);
EOF
    sys::Chk

    sys::Write <<EOF --append  "$(pwd)/common/gtk-3.0/3.20/sass/_colors.scss"

// HOT color
\$hot_color: #$THEME_COLOR_HOTHOT_HEX;
EOF


    # Patch gtk3: .titlebar, decoration, scrollbar slider + 3.26 COMPAT

    sys::PatchText <<'EOF' common/gtk-3.0/3.20/sass/_applications.scss
@@ -562,7 +562,6 @@
     border: 1px solid rgba(0, 0, 0, 0.35);
     border-radius: 3px;
     box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
-    background-image: linear-gradient(to bottom, white);
     background-color: transparent;

   .title, .label {
EOF

    sys::PatchText <<'EOF' common/gtk-3.0/3.20/sass/_drawing.scss
@@ -16,7 +16,6 @@
     color: $text_color;
     border-color: $entry_border;
     background-color: $entry_bg;
-    background-image: linear-gradient(to bottom, $entry_bg);
   }

   @if $t==focus {
@@ -26,7 +25,6 @@
     color: $text_color;
     border-color: if($variant=='light', $selected_bg_color, $button_border);
     background-color: $entry_bg;
-    background-image: linear-gradient(to bottom, $entry_bg);

     @if $variant == 'dark' {
       box-shadow: inset 1px 0 $selected_bg_color,
@@ -43,7 +41,6 @@
     color: $insensitive_fg_color;
     border-color: transparentize($entry_border, 0.45);
     background-color: transparentize($entry_bg, 0.45);
-    background-image: linear-gradient(to bottom, transparentize($entry_bg, 0.45));
   }

   @if $t==header-normal {
@@ -53,8 +50,7 @@

     color: $header_fg;
     border-color: $header_entry_border;
-    background-image: linear-gradient(to bottom, $header_entry_bg);
-    background-color: transparent;
+    background-color: $header_entry_bg;

     image, image:hover { color: inherit; }
   }
@@ -65,7 +61,7 @@
   //
     color: $selected_fg_color;
     border-color: if($darker=='false' and $variant=='light', $selected_bg_color, transparent);
-    background-image: linear-gradient(to bottom, $selected_bg_color);
+    background-color: $selected_bg_color;
   }

   @if $t==header-insensitive {
@@ -73,7 +69,7 @@
   // insensitive header-bar entry
   //
     color: transparentize($header_fg, 0.45);
-    background-image: linear-gradient(to bottom, transparentize($header_entry_bg, 0.15));
+    background-color: transparentize($header_entry_bg, 0.15);
   }

   @else if $t==osd {
@@ -82,8 +78,7 @@
   //
     color: $osd_fg_color;
     border-color: $osd_entry_border;
-    background-image: linear-gradient(to bottom, $osd_entry_bg);
-    background-color: transparent;
+    background-color: $osd_entry_bg;

     image, image:hover { color: inherit; }
   }
@@ -94,7 +89,7 @@
   //
     color: $selected_fg_color;
     border-color: $osd_entry_border;
-    background-image: linear-gradient(to bottom, $selected_bg_color);
+    background-color: $selected_bg_color;
   }

   @else if $t==osd-insensitive {
@@ -102,7 +97,7 @@
   // insensitive osd entry
   //
     color: transparentize($osd_fg_color, 0.45);
-    background-image: linear-gradient(to bottom, transparentize($osd_entry_bg, 0.15));
+    background-color: transparentize($osd_entry_bg, 0.15);
   }
 }

@@ -342,7 +337,7 @@
   $_gradient_repeat: repeat-x;
   $_bg_pos: center $p;

-  background-color: transparent; // shouldn't be needed, but better to be sure;
+  background-color: $_gradient_dir;

   @if ($p == left) or ($p == right) {
     $_gradient_dir: top;
@@ -351,10 +346,6 @@
     $_bg_pos: $p center;
   }

-  background-image: linear-gradient(to $_gradient_dir, // this is the dashed line
-                                    $_undershoot_color_light 50%,
-                                    $_undershoot_color_dark 50%);
-
   padding-#{$p}: 1px;
   background-size: $_dash_bg_size;
   background-repeat: $_gradient_repeat;
EOF


    sys::PatchText <<'EOF' common/gtk-3.0/3.20/sass/_common.scss
@@ -3,7 +3,7 @@
 }

 $ease-out-quad: cubic-bezier(0.25, 0.46, 0.45, 0.94);
-$backdrop_transition: 200ms ease-out;
+$backdrop_transition: none;
 $asset_suffix: if($variant=='dark', '-dark', ''); // use dark assets in dark variant
 $darker_asset_suffix: if($darker=='true', '-dark', $asset_suffix);

@@ -239,13 +239,13 @@
     &.#{$e_type} {
       color: $selected_fg_color;
       border-color: if($variant=='light', $e_color, $entry_border);
-      background-image: linear-gradient(to bottom, mix($e_color, $base_color, 60%));
+      background-color: mix($e_color, $base_color, 60%);

       image { color: $selected_fg_color; }

       &:focus {
         color: $selected_fg_color;
-        background-image: linear-gradient(to bottom, $e_color);
+        background-color: $e_color;
         box-shadow: none;
       }
       selection, selection:focus {
@@ -919,10 +919,6 @@
   box-shadow: none;
   border-width: 0 0 1px 0;
   border-style: solid;
-  border-image: linear-gradient(to bottom, opacify($header_bg, 1),
-                                           darken($header_bg, 7%)) 1 0 1 0; //temporary hack for rhythmbox 3.1
-
-  //&:backdrop { background-color: opacify($header_bg_backdrop, 1); }

   separator { @extend %header_separator; }

@@ -968,7 +964,7 @@
   border-style: solid;
   border-color: opacify($header_border, 1);

-  color: $header_fg;
+  color: $hot_color;
   background-color: opacify($header_bg, 1);
   box-shadow: inset 0  1px lighten($header_bg, 3%);

@@ -1096,7 +1092,7 @@
     }
   }

-  > separator { background-image: linear-gradient(to top, $header_border); }
+  > separator { background-color: $header_border; }

   @extend %titlebar;
 }
@@ -1106,11 +1102,7 @@
   min-height: 1px;
   background: none;
   border-width: 0 1px;
-  border-image: linear-gradient(to bottom,
-                                transparentize($header_fg, 1) 25%,
-                                transparentize($header_fg, 0.65) 25%,
-                                transparentize($header_fg, 0.65) 75%,
-                                transparentize($header_fg, 1) 75%) 0 1/0 1px stretch;
+  border-color: transparentize($header_fg, 0.65);

   &:backdrop { opacity: 0.6; }
 }
@@ -1147,11 +1139,11 @@
       &.#{$e_type} {
         color: $selected_fg_color;
         border-color: if($darker=='false' and $variant=='light', $e_color, $header_entry_border);
-        background-image: linear-gradient(to bottom, mix($e_color, $header_bg, 60%));
+        background-color: mix($e_color, $header_bg, 60%);

         &:focus {
           color: $selected_fg_color;
-          background-image: linear-gradient(to bottom, $e_color);
+          background-color: $e_color;
         }
         selection, selection:focus {
           background-color: $selected_fg_color;
@@ -1474,17 +1466,17 @@
   &.progressbar, &.progressbar:focus { // progress bar in treeviews
     color: $selected_fg_color;
     border-radius: 3px;
-    background-image: linear-gradient(to bottom, $selected_bg_color);
+    background-color: $selected_bg_color;

     &:selected, &:selected:focus {
       color: $selected_bg_color;
       box-shadow: none;
-      background-image: linear-gradient(to bottom, $selected_fg_color);
+      background-color: $selected_fg_color;
     }
   }
   &.trough, &.trough:selected, &.trough:selected:focus { // progress bar trough in treeviews
     color: $fg_color;
-    background-image: linear-gradient(to bottom, $button_border);
+    background-color: $button_border;
     border-radius: 3px;
     border-width: 0;
   }
@@ -1503,11 +1495,6 @@
       background-image: none;
       border-style: none solid none none;
       border-radius: 0;
-      border-image: linear-gradient(to bottom,
-                                    $base_color 20%,
-                                    transparentize(if($variant == 'light', black, white), 0.89) 20%,
-                                    transparentize(if($variant == 'light', black, white), 0.89) 80%,
-                                    $base_color 80%) 0 1 0 0 / 0 1px 0 0 stretch;

       &:hover { color: $selected_bg_color; }
       &:active { color: $fg_color; }
@@ -1881,11 +1868,11 @@
     border: 4px solid transparent;
     border-radius: 8px;
     background-clip: padding-box;
-    background-color: mix($fg_color, $bg_color, 40%);
+    background-color: $selected_bg_color;

-    &:hover { background-color: mix($fg_color, $bg_color, 30%); }
+    &:hover { background-color: $selected_bg_color; }

-    &:hover:active { background-color: $selected_bg_color;}
+    &:hover:active { background-color: $warning_color;}

     &:disabled { background-color: transparent; }
   }
@@ -1910,7 +1897,7 @@
         margin: 0;
         min-width: 4px;
         min-height: 4px;
-        background-color: mix($fg_color, $bg_color, 70%);
+        background-color: $selected_bg_color;
         border: 1px solid if($variant == 'light', transparentize(white, 0.4), transparentize(black, 0.7));
       }

@@ -1937,8 +1924,6 @@
 // Switches
 //
 switch {
-  font: 1;
-
   min-width: 52px;
   min-height: 24px;

@@ -2383,6 +2368,8 @@
     border-style: none;
   }

+  /* DEV: Removed because of lagging
+
   // This is used by GtkScrolledWindow, when content is touch-dragged past boundaries.
   // This draws a box on top of the content, the size changes programmatically.
   overshoot {
@@ -2400,10 +2387,10 @@
     &.right { @include undershoot(right); }
   }

+  */
+
   junction { // the small square between two scrollbars
     border-color: transparent;
-    // the border image is used to add the missing dot between the borders, details, details, details...
-    border-image: linear-gradient(to bottom, $borders_color 1px, transparent 1px) 0 0 0 1 / 0 1px stretch;
     background-color: $_scrollbar_bg_color;

     &:dir(rtl) { border-image-slice: 0 1 0 0; }
@@ -2681,7 +2668,7 @@
     &.sidebar-placeholder-row {
       padding: 0 8px;
       min-height: 2px;
-      background-image: linear-gradient(to top, $drop_target_color);
+      background-color: $drop_target_color;
       background-clip: content-box;
     }

@@ -2730,17 +2717,15 @@
     min-height: 1px;
     -gtk-icon-source: none;
     border-style: none;
-    background-color: transparent;
-    background-image: linear-gradient(to top, $borders_color);
+    background-color: $borders_color;
     background-size: 1px 1px;

-    &:selected { background-image: linear-gradient(to top, $selected_bg_color); }
+    &:selected { background-color: $selected_bg_color; }

     &.wide {
       min-width: 5px;
       min-height: 5px;
       background-color: $bg_color;
-      background-image: linear-gradient(to top, $borders_color), linear-gradient(to top, $borders_color);
       background-size: 1px 1px, 1px 1px;
     }
   }
@@ -2997,7 +2982,7 @@

 // Decouple the font of context menus from their entry/textview
 .context-menu { font: initial; }
-.monospace { font: Monospace; }
+.monospace { font-family: Monospace; }

 //
 // Shortcuts Help
@@ -3049,19 +3034,13 @@

   $_wm_border: if($variant=='light', transparentize(black, 0.9), transparentize(black, 0.45));

-  box-shadow: 0 0 0 1px if($darker=='true' or $variant == 'dark', darken($header_bg, 7%), $_wm_border),
-              0 8px 8px 0 if($variant == 'light', opacify($_wm_border, 0.1), transparentize($_wm_border, 0.2));
+  box-shadow: 0 2px 2px 2px rgba(0, 0, 0, 0.4);

   // this is used for the resize cursor area
   margin: 10px;

   &:backdrop {
-    // the transparent shadow here is to enforce that the shadow extents don't
-    // change when we go to backdrop, to prevent jumping windows
-    box-shadow: 0 0 0 1px if($darker=='true' or $variant == 'dark', transparentize(darken($header_bg, 7%), 0.1), $_wm_border),
-                0 8px 8px 0 transparent,
-                0 5px 5px 0 if($variant == 'light', opacify($_wm_border, 0.1), transparentize($_wm_border, 0.2));
-
+    box-shadow: 0 2px 2px 2px rgba(0, 0, 0, 0.4);
     transition: $backdrop_transition;
   }
   .fullscreen &,
@@ -3075,14 +3054,13 @@
   // server-side decorations as used by mutter
   .ssd & {
     border-radius: if($darker=='false' and $variant=='light', 4px 4px 0 0, 3px 3px 0 0);
-    box-shadow: 0 0 0 1px if($darker=='true' or $variant == 'dark', transparentize(black, 0.35), $_wm_border);
+    box-shadow: none;

     &.maximized { border-radius: 0; }
   }
   .csd.popup & {
     border-radius: 2px;
-    box-shadow: 0 3px 6px if($variant == 'light', $_wm_border, transparentize($_wm_border, 0.1)),
-                0 0 0 1px if($variant == 'light', $_wm_border, darken($bg_color, 10%));
+    box-shadow: 0 2px 2px 2px rgba(0, 0, 0, 0.3);
   }
   tooltip.csd & {
     border-radius: 2px;
@@ -3156,3 +3134,7 @@
     &:disabled { color: mix($selected_fg_color, $selected_bg_color, 50%); }
   }
 }
+.titlebar { font-weight: bold; }
+
+/* Fix gthumb selected item */
+widget.view:selected { background-color: rgba(23,77,141,.3); }
EOF


    # Unused includes
    sed -i -E \
        -e "s#@import 'unity';##" \
        -e "s#@import 'granite';##" \
        -e "s#@import 'lightdm';##" \
        -e "s#@import 'transparent_widgets';##" \
        common/gtk-3.0/3.20/sass/gtk-solid-dark.scss
    sys::Chk


    # Patch gtk2 menubar
    # SetupArcThemeSources::BackupFile common/gtk-2.0/menubar-toolbar/menubar-toolbar-dark.rc

    # DEV: Commenting out hardcoded PNGs as no source svg is provided
    sys::PatchText <<'EOF' common/gtk-2.0/menubar-toolbar/menubar-toolbar-dark.rc
@@ -10,15 +10,8 @@
   xthickness = 0
   ythickness = 0

-  engine "pixmap" {
+  # engine "pixmap" { DEV: Removed bitmaps as no sources are provided to patch }

-    image {
-      function = BOX
-      file  = "menubar-toolbar/menubar-dark.png"
-      stretch  = TRUE
-      border = { 1, 1, 1, 1 }
-    }
-  }
 }

 style "menubar-borderless" {
@@ -47,6 +40,7 @@
   xthickness = 2
   ythickness = 4

+  #fg[NORMAL] = "#480048"
   fg[PRELIGHT] = @selected_fg_color

   engine "pixmap" {
@@ -54,7 +48,7 @@
     image {
       function = BOX
       state = PRELIGHT
-      file = "menubar-toolbar/menubar_button-dark.png"
+      file = "assets/menubar_button.png"
       border = { 2, 2, 2, 2 }
       stretch = TRUE
     }
@@ -89,40 +83,8 @@
   xthickness = 4
   ythickness = 4

-  engine "pixmap" {
+  # engine "pixmap" { DEV: Removed bitmaps as no sources are provided to patch }

-    image {
-      function = BOX
-      state = NORMAL
-      file = "menubar-toolbar/button.png"
-      border = { 4, 4, 4, 4 }
-      stretch = TRUE
-    }
-
-    image {
-      function = BOX
-      state = PRELIGHT
-      file = "menubar-toolbar/button-hover.png"
-      border = { 4, 4, 4, 4 }
-      stretch = TRUE
-    }
-
-    image {
-      function = BOX
-      state = ACTIVE
-      file = "menubar-toolbar/button-active.png"
-      border = { 4, 4, 4, 4 }
-      stretch = TRUE
-    }
-
-    image {
-      function = BOX
-      state = INSENSITIVE
-      file = "menubar-toolbar/button-insensitive.png"
-      border = { 4, 4, 4, 4 }
-      stretch = TRUE
-    }
-  }
 }

 style "toolbar_entry" {
@@ -133,55 +95,7 @@

   text[NORMAL] = "#afb8c5"

-  engine "pixmap" {
-
-    image {
-      function = SHADOW
-      state = NORMAL
-      detail = "entry"
-      file = "menubar-toolbar/entry-toolbar-dark.png"
-      border = {6, 6, 6, 6}
-      stretch = TRUE
-    }
-
-    image {
-      function = SHADOW
-      state = ACTIVE
-      detail = "entry"
-      file = "menubar-toolbar/entry-active-toolbar-dark.png"
-      border = {6, 6, 6, 6}
-      stretch = TRUE
-    }
-
-    image {
-      function = SHADOW
-      state = INSENSITIVE
-      detail = "entry"
-      file = "menubar-toolbar/entry-disabled-toolbar-dark.png"
-      border = {6, 6, 6, 6}
-      stretch = TRUE
-    }
-
-    image {
-      function = FLAT_BOX
-      state    = ACTIVE
-      detail   = "entry_bg"
-      file     = "assets/null.png"
-    }
-
-    image {
-      function = FLAT_BOX
-      state    = INSENSITIVE
-      detail   = "entry_bg"
-      file     = "assets/null.png"
-    }
-
-    image {
-      function = FLAT_BOX
-      detail   = "entry_bg"
-      file     = "assets/null.png"
-    }
-  }
+  # engine "pixmap" { DEV: Removed bitmaps as no sources are provided to patch }
 }

 #Chromium
EOF
    sys::Chk

    # Patch gtk2 main: remove adwaita engine
    # SetupArcThemeSources::BackupFile common/gtk-2.0/main.rc
    sys::PatchText <<'EOF' common/gtk-2.0/main.rc
@@ -533,8 +533,6 @@

 style "toplevel_hack" {

-  engine "adwaita" {
-  }
 }

 style "ooo_stepper_hack" {
@@ -701,8 +699,6 @@

 style "menu_framed_box" {

-  engine "adwaita" {
-  }
 }

 style "menu_item"
EOF
    sys::Chk


    # Patch Arc theme colors
    while IFS= read -r -d $'\0' file || [[ -n $file ]] ; do

        sed -i -E \
            -e "s/#(383c4a|2b2e39|343743|202128|262934|2f343f|353945|3e4350|3e4351|303440|3e4350|313541|767b87|8f939d|414857|353a47)/#$THEME_COLOR_WINDOW_HEX/gi" \
            -e "s/#(404552|262933|444a58|505666|2d323d|3e434f|5b627b)/#$THEME_COLOR_BACKGD_HEX/gi" \
            -e "s/#(afb8c5|d3dae3|bac3cf|b9bcc2)/#$THEME_COLOR_FOREGD_HEX/gi" \
            -e "s/#(5294e2|2e3340|282b36|4dadd4)/#$THEME_COLOR_SELECT_HEX/gi" \
            -e "s/#cc575d/#$THEME_COLOR_HOTHOT_HEX/gi" \
            -e "s/#d7787d/#$THEME_COLOR_MANAGE_HEX/gi" \
            -e "s/#2d323f/#$THEME_COLOR_OBJECT_HEX/gi" \
            -e "s/#(2d303b|545860|39404d)/#3f3f3f/gi" \
            -e "s/#be3841/#dc322f/gi" \
            "$file" # > "$tmpfile"

        # if [[ "$( md5sum $file | awk '{printf $1}' )" != "$( md5sum $tmpfile | awk '{printf $1}' )" ]] ; then
        #     SetupArcThemeSources::BackupFile "$file"
        #     cp "$tmpfile" "$file"
        #     sys::Msg "Patched $file"
        # fi
    done < <( \
            find -L common/gnome-shell/3.20 \( -name "*.svg" -o -name "*.scss" \) -print0
            find -L common/gtk-2.0          \( -name "*.svg" -o -name "*rc*"   \) -print0
            find -L common/gtk-3.0/3.20     \( -name "*.svg" -o -name "*.scss" \) -print0
            )

    popd

    chown -hR 1000:1000 "$srcPath"
    chmod -R  755       "$srcPath"
}



BuildPatchedArcTheme () # $1:SRC_PATH $2:DST_PATH
{
    # ARGS

    [[ $# -ne 2 ]] && sys::Die "BuildPatchedArcTheme: invalid arguments"

    local srcPath=$1 dstPath=$( readlink -f $2 )

    [[ -d "$srcPath/common/gtk-3.0/3.20/" ]] || sys::Die "BuildPatchedArcTheme: Invalid theme source path: $srcPath"

    [[ -e "$dstPath" ]] && sys::Die "BuildPatchedArcTheme: $dstPath already exists, remove it first"


    # COMPILE

    pushd "$srcPath/common/gnome-shell/3.20/"
    sudo --set-home -u \#1000 bash -c '. ~/.nvm/nvm.sh && gulp'
    sys::Chk
    popd

    pushd "$srcPath/common/gtk-2.0/"
    rm -rf ./assets-dark/*
    sudo --set-home -u \#1000 bash -c './render-dark-assets.sh'
    sys::Chk
    popd

    pushd "$srcPath/common/gtk-3.0/3.20/"
    rm -rf ./assets/*
    sudo --set-home -u \#1000 bash -c './render-assets.sh'
    sys::Chk
    sudo --set-home -u \#1000 bash -c '. ~/.nvm/nvm.sh && gulp'
    sys::Chk
    popd


    # PATCH

    # Patch gtk2: swap scrollbar sliders
    pushd "$srcPath"
    mv  common/gtk-2.0/assets-dark/slider-vert-active.png \
        common/gtk-2.0/assets-dark/slider-vert.png.NEW
    mv  common/gtk-2.0/assets-dark/slider-vert-insens.png \
        common/gtk-2.0/assets-dark/slider-vert-active.png
    mv  common/gtk-2.0/assets-dark/slider-vert.png \
        common/gtk-2.0/assets-dark/slider-vert-insens.png
    mv  common/gtk-2.0/assets-dark/slider-vert.png.NEW \
        common/gtk-2.0/assets-dark/slider-vert.png

    mv  common/gtk-2.0/assets-dark/slider-horiz-active.png \
        common/gtk-2.0/assets-dark/slider-horiz.png.NEW
    mv  common/gtk-2.0/assets-dark/slider-horiz-insens.png \
        common/gtk-2.0/assets-dark/slider-horiz-active.png
    mv  common/gtk-2.0/assets-dark/slider-horiz.png \
        common/gtk-2.0/assets-dark/slider-horiz-insens.png
    mv  common/gtk-2.0/assets-dark/slider-horiz.png.NEW \
        common/gtk-2.0/assets-dark/slider-horiz.png
    popd




    # COPY

    # GS
    sys::Copy "$srcPath/common/gnome-shell/3.20/common-assets/" \
        "$dstPath/gnome-shell/"
    sys::Copy "$srcPath/common/gnome-shell/3.20/dark-assets/" \
        "$dstPath/gnome-shell/"
    sys::Copy "$srcPath/common/gnome-shell/3.20/gnome-shell-dark.css" \
        "$dstPath/gnome-shell/gnome-shell.css"

    # GTK2
    sys::Copy "$srcPath/common/gtk-2.0/menubar-toolbar/" \
        "$dstPath/gtk-2.0/"
    sys::Copy --rename "$srcPath/common/gtk-2.0/assets-dark/" \
        "$dstPath/gtk-2.0/assets/"
    sys::Copy "$srcPath/common/gtk-2.0/gtkrc-dark" \
        "$dstPath/gtk-2.0/gtkrc"
    for rc in apps main panel xfce-notify; do
        sys::Copy "$srcPath/common/gtk-2.0/$rc.rc" "$dstPath/gtk-2.0/"
    done

    # GTK3
    sys::Copy "$srcPath/common/gtk-3.0/3.20/assets/" \
        "$dstPath/gtk-3.0/"
    sys::Copy "$srcPath/common/gtk-3.0/3.20/gtk-solid-dark.css" \
        "$dstPath/gtk-3.0/gtk.css"

    # GTK3: arc-flatabulous overrides titlebutton-*
    sys::Copy "$srcPath/arc-flatabulous-theme-master/common/gtk-3.0/3.20/assets/" \
          "$dstPath/gtk-3.0/"

    # GS EXT window_buttons: arc-flatabulous theme
    local wbTheme=$dstPath/gnome-shell/extensions/window_buttons.theme
    for png in "$dstPath/gtk-3.0/assets/titlebutton"-{close,maximize,minimize}{,-hover,-active}.png ; do
        sys::Copy "$png" "$wbTheme/"
    done

    sys::Write <<'EOF' "$wbTheme/style.css"
.box-bin            { padding-right: 8px; }
.button-box         { spacing: 12px; }
.window-button      { width: 14px; height: 14px; }
.close              { background-image: url("titlebutton-close.png"); }
.close:hover        { background-image: url("titlebutton-close-hover.png"); }
.close:active       { background-image: url("titlebutton-close-active.png"); }
.maximize           { background-image: url("titlebutton-maximize.png"); }
.maximize:hover     { background-image: url("titlebutton-maximize-hover.png"); }
.maximize:active    { background-image: url("titlebutton-maximize-active.png"); }
.minimize           { background-image: url("titlebutton-minimize.png"); }
.minimize:hover     { background-image: url("titlebutton-minimize-hover.png"); }
.minimize:active    { background-image: url("titlebutton-minimize-active.png"); }
EOF


    # OTHER Styles

    BuildKvantumStyles "$dstPath/kvantum"

    BuildBrandingStyles "$dstPath/branding"

    BuildSublimeStyles "$dstPath/sublime-text"

    BuildGtkSourceStyles "$dstPath/gtk-source"

    BuildAudacityStyles "$dstPath/audacity"

    # OLD BuildFirefoxStyles "$dstPath/firefox"

    # CLEAN
    chown -hR 1000:1000 "$dstPath"

    find "$dstPath" -type d -exec chmod 0755 {} \;
    find "$dstPath" -type f -exec chmod 0644 {} \;
}




BuildKvantumStyles() # $1:PATH
{
    sys::Mkdir "$1"

    net::Download \
        https://raw.githubusercontent.com/tsujan/Kvantum/master/Kvantum/themes/kvthemes/KvArcDark/KvArcDark.kvconfig \
        "$1/$THEME_GTK.kvconfig"
        
    net::Download \
        https://raw.githubusercontent.com/tsujan/Kvantum/master/Kvantum/themes/kvthemes/KvArcDark/KvArcDark.svg \
        "$1/$THEME_GTK.svg"

    sed -i -E \
        -e "s/#(383c4a|2b2e39|343743|202128|262934|2f343f|353945|3e4350|3e4351|303440|3e4350|313541|767b87|8f939d|414857|353a47)/#$THEME_COLOR_WINDOW_HEX/gi" \
        -e "s/#(404552|262933|444a58|505666|2d323d|3e434f|5b627b)/#$THEME_COLOR_BACKGD_HEX/gi" \
        -e "s/#(afb8c5|d3dae3|bac3cf|b9bcc2)/#$THEME_COLOR_FOREGD_HEX/gi" \
        -e "s/#(5294e2|2e3340|282b36|4dadd4)/#$THEME_COLOR_SELECT_HEX/gi" \
        -e "s/#cc575d/#$THEME_COLOR_HOTHOT_HEX/gi" \
        -e "s/#d7787d/#$THEME_COLOR_MANAGE_HEX/gi" \
        -e "s/#2d323f/#$THEME_COLOR_OBJECT_HEX/gi" \
        -e "s/#(2d303b|545860|39404d)/#3f3f3f/gi" \
        -e "s/#be3841/#dc322f/gi" \
        "$1/$THEME_GTK".*
}




BuildGtkSourceStyles() # $1:PATH
{
    sys::Mkdir "$1"
    sys::Write <<EOF "$1/classic-override.xml" 0:0 755
<?xml version="1.0" encoding="UTF-8"?>
<!--
FROM: https://wiki.gnome.org/Projects/GtkSourceView/StyleSchemes?action=AttachFile&do=view&target=tomorrow_night-eighties.xml
BASE: https://github.com/chriskempson/tomorrow-theme
-->

<style-scheme id="classic" _name="$THEME_GTK" version="1.0">
  <author>$THEME_GTK</author>
  <_description>$THEME_GTK</_description>

  <style name="text" foreground="#$THEME_COLOR_FOREGD_HEX" background="#$THEME_COLOR_BACKGD_HEX"/>
  <style name="selection" foreground="#ffffff" background="#$THEME_COLOR_SELECT_HEX"/>
  <style name="line-numbers" foreground="#$THEME_COLOR_OBJECT_HEX" background="#$THEME_COLOR_BACKGD_HEX"/>
  <style name="def:builtin" foreground="#f99157"/>
  <style name="background-pattern" background="#000000"/>
  <style name="bracket-match"  background="#393939" bold="true"/>
  <style name="bracket-mismatch"  background="#393939" underline="true"/>
  <style name="css:at-rules" foreground="#C45837"/>
  <style name="css:color" foreground="#cccccc"/>
  <style name="css:keyword" foreground="#ffcc66"/>
  <style name="current-line"  background="#393939"/>
  <style name="cursor" foreground="#cccccc"/>
  <style name="def:base-n-integer" foreground="#f99157"/>
  <style name="def:boolean" foreground="#f99157"/>
  <style name="def:character" foreground="#f99157"/>
  <style name="def:comment" foreground="#999999"/>
  <style name="def:complex" foreground="#f99157"/>
  <style name="def:decimal" foreground="#f99157"/>
  <style name="def:doc-comment" foreground="#999999"/>
  <style name="def:doc-comment-element" foreground="#999999"/>
  <style name="def:error" foreground="#cdcdcd" background="#f2777a"/>
  <style name="def:floating-point" foreground="#f99157"/>
  <style name="def:function" foreground="#6699cc"/>
  <style name="def:identifier" foreground="#f2777a"/>
  <style name="def:keyword" foreground="#C45837"/>
  <style name="def:note" foreground="#999999"/>
  <style name="def:number" foreground="#f99157"/>
  <style name="def:operator" foreground="#66cccc"/>
  <style name="def:preprocessor" foreground="#f99157"/>
  <style name="def:reserved" foreground="#C45837"/>
  <style name="def:shebang" foreground="#999999"/>
  <style name="def:special-char" foreground="#f99157"/>
  <style name="def:special-constant" foreground="#f99157"/>
  <style name="def:statement" foreground="#C45837"/>
  <style name="def:string" foreground="#99cc99"/>
  <style name="def:type" foreground="#ffcc66"/>
  <style name="draw-spaces" foreground="#6a6a6a"/>
  <style name="html:dtd" foreground="#99cc99"/>
  <style name="html:tag" foreground="#f2777a"/>
  <style name="js:function" foreground="#6699cc"/>
  <style name="perl:builtin" foreground="#6699cc"/>
  <style name="perl:include-statement" foreground="#C45837"/>
  <style name="perl:special-variable" foreground="#f99157"/>
  <style name="perl:variable" foreground="#f2777a"/>
  <style name="php:string" foreground="#99cc99"/>
  <style name="python:builtin-constant" foreground="#C45837"/>
  <style name="python:builtin-function" foreground="#6699cc"/>
  <style name="python:module-handler" foreground="#C45837"/>
  <style name="python:special-variable" foreground="#C45837"/>
  <style name="ruby:attribute-definition" foreground="#C45837"/>
  <style name="ruby:builtin" foreground="#f2777a"/>
  <style name="ruby:class-variable" foreground="#f2777a"/>
  <style name="ruby:constant" foreground="#f2777a"/>
  <style name="ruby:global-variable" foreground="#6699cc"/>
  <style name="ruby:instance-variable" foreground="#f2777a"/>
  <style name="ruby:module-handler" foreground="#C45837"/>
  <style name="ruby:predefined-variable" foreground="#f99157"/>
  <style name="ruby:regex" foreground="#99cc99"/>
  <style name="ruby:special-variable" foreground="#C45837"/>
  <style name="ruby:symbol" foreground="#99cc99"/>
  <style name="rubyonrails:attribute-definition" foreground="#C45837"/>
  <style name="rubyonrails:block-parameter" foreground="#f99157"/>
  <style name="rubyonrails:builtin" foreground="#f2777a"/>
  <style name="rubyonrails:class-inherit" foreground="#99cc99"/>
  <style name="rubyonrails:class-name" foreground="#ffcc66"/>
  <style name="rubyonrails:class-variable" foreground="#f2777a"/>
  <style name="rubyonrails:complex-interpolation" foreground="#f99157"/>
  <style name="rubyonrails:constant" foreground="#f2777a"/>
  <style name="rubyonrails:global-variable" foreground="#6699cc"/>
  <style name="rubyonrails:instance-variable" foreground="#f2777a"/>
  <style name="rubyonrails:module-handler" foreground="#C45837"/>
  <style name="rubyonrails:module-name" foreground="#ffcc66"/>
  <style name="rubyonrails:predefined-variable" foreground="#f99157"/>
  <style name="rubyonrails:rails" foreground="#f2777a"/>
  <style name="rubyonrails:regex" foreground="#99cc99"/>
  <style name="rubyonrails:simple-interpolation" foreground="#f99157"/>
  <style name="rubyonrails:special-variable" foreground="#C45837"/>
  <style name="rubyonrails:symbol" foreground="#99cc99"/>
  <style name="search-match"  background="#393939" bold="true" underline="true"/>
  <style name="xml:attribute-name" foreground="#f2777a"/>
  <style name="xml:doctype" foreground="#f2777a"/>
  <style name="xml:element-name" foreground="#f2777a"/>
  <style name="xml:namespace" foreground="#f2777a"/>
  <style name="xml:tag" foreground="#f2777a"/>

  <!-- meld -->
  <style name="meld:insert" background="#113800" foreground="#4e9a06" line-background="#309900"/>
  <style name="meld:inline" background="#rgba(255, 255, 255, 0.07)"/>
  <style name="meld:replace" background="#002142" foreground="#2d6cfc" line-background="#0066cc"/>
  <style name="meld:conflict" background="#3D1514" foreground="#ff0000" line-background="#ac3b39"/>
  <style name="meld:current-chunk-highlight" background="#rgba(0, 0, 0, 0.40)"/>
  <style name="meld:current-line-highlight" background="#000000"/>

</style-scheme>
EOF
  # TODO test these:
  #   <style name="meld:delete" background="#ffffff" foreground="#a40000" line-background="#cccccc"/>
  #   <style name="meld:error" background="#fce94f" foreground="#faad3d" line-background="#fdf8cd"/>
  #   <style name="meld:unknown-text" foreground="#aaaaaa"/>
  #   <style name="meld:syncpoint-outline" foreground="#bbbbbb"/>
  #   <style name="meld:dimmed" foreground="#999999"/>

}




BuildBrandingStyles () # $1:PATH
{
    sys::Mkdir "$1"

    # BRANDING
    # mkdir -p "$dstPath/branding"
    sys::Write <<'EOF' "$1/logo.bash" 0:0 755
#!/bin/bash
echo -e "\
             \e[38;2;45;39;35m\e[48;2;24;22;20m▄\e[38;2;60;52;46m\e[48;2;27;24;22m▄\e[38;2;71;62;55m\e[48;2;32;28;25m▄\e[38;2;72;62;55m\e[48;2;43;38;33m▄\e[38;2;72;62;55m\e[48;2;53;47;41m▄\e[38;2;72;62;55m\e[48;2;61;52;46m▄\e[38;2;72;62;55m\e[48;2;65;57;50m▄\e[38;2;72;62;55m\e[48;2;68;59;51m▄\e[38;2;72;62;55m\e[48;2;68;59;51m▄\e[38;2;72;62;55m\e[48;2;65;57;50m▄\e[38;2;72;62;55m\e[48;2;60;52;46m▄\e[38;2;72;62;55m\e[48;2;53;46;41m▄\e[38;2;72;62;55m\e[48;2;43;37;33m▄\e[38;2;71;62;55m\e[48;2;32;28;25m▄\e[38;2;59;51;46m\e[48;2;27;24;22m▄\e[38;2;44;39;34m\e[48;2;24;22;20m▄\e[38;2;31;28;25m\e[48;2;24;22;20m▄\e[0m           $(:                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     )
         \e[48;2;24;22;20m\e[38;2;40;35;32m▄\e[48;2;28;25;23m\e[38;2;63;54;48m▄\e[48;2;48;42;38m\e[38;2;72;62;55m▄\e[48;2;67;57;51m\e[38;2;72;62;55m▄\e[48;2;72;62;54m\e[38;2;71;61;54m▄\e[48;2;72;62;55m\e[38;2;71;61;54m▄\e[48;2;71;61;54m\e[38;2;72;62;55m▄\e[48;2;71;61;54m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;73;62;55m▄\e[48;2;72;62;55m\e[38;2;73;62;55m▄\e[48;2;72;62;55m\e[38;2;70;62;55m▄\e[48;2;73;62;55m\e[38;2;65;60;57m▄\e[48;2;73;62;55m\e[38;2;65;60;57m▄\e[48;2;72;62;55m\e[38;2;70;62;56m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;73;62;55m▄\e[48;2;71;61;54m\e[38;2;72;62;55m▄\e[48;2;71;61;54m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;71;61;54m▄\e[48;2;72;61;55m\e[38;2;71;61;54m▄\e[48;2;66;57;51m\e[38;2;72;62;55m▄\e[48;2;49;43;38m\e[38;2;72;62;55m▄\e[48;2;30;27;24m\e[38;2;64;55;49m▄\e[48;2;24;22;20m\e[38;2;40;35;31m▄\e[0m        $(:                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       )
      \e[48;2;24;22;20m\e[38;2;25;23;20m▄\e[48;2;24;22;20m\e[38;2;52;44;40m▄\e[48;2;48;42;38m\e[38;2;72;62;54m▄\e[48;2;70;61;54m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;71;61;54m▄\e[48;2;71;61;54m\e[38;2;72;62;55m▄\e[48;2;71;61;54m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;74;62;54m▄\e[48;2;72;62;55m\e[38;2;74;62;54m▄\e[48;2;74;62;54m\e[38;2;65;60;58m▄\e[48;2;70;62;56m\e[38;2;74;62;54m▄\e[48;2;67;61;57m\e[38;2;127;74;39m▄\e[48;2;78;63;53m\e[38;2;223;95;9m▄\e[48;2;160;81;29m\e[38;2;255;103;0m▄\e[48;2;160;81;29m\e[38;2;255;103;0m▄\e[48;2;78;62;52m\e[38;2;226;94;6m▄\e[48;2;67;61;56m\e[38;2;129;72;34m▄\e[48;2;70;62;56m\e[38;2;75;62;54m▄\e[48;2;74;62;54m\e[38;2;65;60;57m▄\e[48;2;72;62;55m\e[38;2;74;63;55m▄\e[48;2;72;62;55m\e[38;2;74;62;54m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;71;61;54m\e[38;2;72;62;55m▄\e[48;2;71;61;54m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;71;61;54m▄\e[48;2;70;60;54m\e[38;2;72;62;55m▄\e[48;2;48;42;37m\e[38;2;71;62;55m▄\e[48;2;24;22;20m\e[38;2;52;46;41m▄\e[48;2;24;22;20m\e[38;2;25;23;21m▄\e[0m     $(:                                                                                                                                                                                                                                                                                                                                                                                                     )
     \e[48;2;25;23;20m\e[38;2;48;42;38m▄\e[48;2;53;46;41m\e[38;2;71;61;54m▄\e[48;2;71;61;54m\e[38;2;71;61;54m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;73;62;55m▄\e[48;2;72;62;55m\e[38;2;73;62;55m▄\e[48;2;75;63;54m\e[38;2;60;60;58m▄\e[48;2;68;61;56m\e[38;2;93;66;49m▄\e[48;2;65;61;57m\e[38;2;172;84;25m▄\e[48;2;111;71;43m\e[38;2;245;100;3m▄\e[48;2;191;88;19m\e[38;2;255;105;0m▄\e[48;2;255;103;0m\e[38;2;253;102;0m▄\e[48;2;255;103;0m\e[38;2;254;102;0m▄\e[48;2;254;102;0m\e[38;2;255;102;0m▄\e[48;2;254;102;0m\e[38;2;255;102;0m▄\e[48;2;255;103;0m\e[38;2;255;102;0m▄\e[48;2;255;103;0m\e[38;2;253;102;0m▄\e[48;2;196;87;14m\e[38;2;255;105;0m▄\e[48;2;112;69;40m\e[38;2;245;99;1m▄\e[48;2;65;60;56m\e[38;2;174;82;22m▄\e[48;2;67;62;57m\e[38;2;97;65;45m▄\e[48;2;75;63;54m\e[38;2;60;59;59m▄\e[48;2;72;62;55m\e[38;2;73;62;55m▄\e[48;2;72;62;55m\e[38;2;73;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;71;61;54m\e[38;2;71;61;54m▄\e[48;2;52;46;41m\e[38;2;72;61;54m▄\e[48;2;25;22;20m\e[38;2;48;42;37m▄\e[0m    $(:                                                                                                                                                                                                                                                                                                                  )
   \e[48;2;24;22;20m\e[38;2;29;26;24m▄\e[48;2;40;34;31m\e[38;2;64;55;49m▄\e[48;2;71;61;54m\e[38;2;72;62;55m▄\e[48;2;71;61;54m\e[38;2;71;61;54m▄\e[48;2;72;62;55m\e[38;2;73;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;73;62;55m\e[38;2;67;61;57m▄\e[48;2;72;62;55m\e[38;2;69;61;56m▄\e[48;2;66;61;57m\e[38;2;124;74;39m▄\e[48;2;72;63;55m\e[38;2;217;94;12m▄\e[48;2;151;79;32m\e[38;2;255;102;0m▄\e[48;2;225;95;9m\e[38;2;255;104;0m▄\e[48;2;255;104;0m\e[38;2;252;101;1m▄\e[48;2;255;102;0m\e[38;2;254;102;0m▄\e[48;2;252;101;1m\e[38;2;255;102;0m▄\e[48;2;255;102;0m\e[38;2;253;101;0m▄\e[48;2;255;102;0m\e[38;2;255;102;0m▄\e[48;2;254;102;0m\e[38;2;255;104;0m▄\e[48;2;254;102;0m\e[38;2;255;104;0m▄\e[48;2;255;102;0m\e[38;2;255;102;0m▄\e[48;2;255;102;0m\e[38;2;253;102;0m▄\e[48;2;253;101;1m\e[38;2;255;102;0m▄\e[48;2;255;103;0m\e[38;2;254;102;0m▄\e[48;2;255;104;0m\e[38;2;252;101;1m▄\e[48;2;227;95;6m\e[38;2;255;104;0m▄\e[48;2;155;78;27m\e[38;2;255;102;0m▄\e[48;2;74;61;53m\e[38;2;218;92;8m▄\e[48;2;65;61;57m\e[38;2;125;72;35m▄\e[48;2;72;62;55m\e[38;2;69;61;56m▄\e[48;2;73;62;55m\e[38;2;66;61;57m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;73;62;55m▄\e[48;2;71;61;54m\e[38;2;71;61;54m▄\e[48;2;71;61;54m\e[38;2;72;62;55m▄\e[48;2;39;34;31m\e[38;2;63;55;49m▄\e[48;2;24;22;20m\e[38;2;29;26;23m▄\e[0m  $(:                                                                                                                                                              )
  \e[48;2;24;22;20m\e[38;2;31;28;25m▄\e[48;2;49;42;38m\e[38;2;66;57;51m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;71;61;54m\e[38;2;71;61;54m▄\e[48;2;73;62;55m\e[38;2;71;62;55m▄\e[48;2;67;61;57m\e[38;2;92;66;49m▄\e[48;2;67;61;56m\e[38;2;162;82;28m▄\e[48;2;103;69;46m\e[38;2;247;101;3m▄\e[48;2;193;89;19m\e[38;2;255;104;0m▄\e[48;2;254;103;0m\e[38;2;255;102;0m▄\e[48;2;255;103;0m\e[38;2;254;102;0m▄\e[48;2;255;102;0m\e[38;2;255;102;0m▄\e[48;2;253;102;1m\e[38;2;255;102;0m▄\e[48;2;255;102;0m\e[38;2;252;101;0m▄\e[48;2;254;102;0m\e[38;2;255;102;0m▄\e[48;2;251;101;1m\e[38;2;255;105;0m▄\e[48;2;255;105;0m\e[38;2;224;94;6m▄\e[48;2;255;103;0m\e[38;2;148;69;18m▄\e[48;2;212;89;8m\e[38;2;56;45;40m▄\e[48;2;211;89;8m\e[38;2;59;51;46m▄\e[48;2;255;101;0m\e[38;2;150;77;29m▄\e[48;2;255;104;0m\e[38;2;225;95;7m▄\e[48;2;252;101;1m\e[38;2;255;104;0m▄\e[48;2;254;102;0m\e[38;2;255;103;0m▄\e[48;2;255;102;0m\e[38;2;252;101;1m▄\e[48;2;253;102;0m\e[38;2;255;102;0m▄\e[48;2;255;102;0m\e[38;2;255;102;0m▄\e[48;2;255;103;0m\e[38;2;254;102;0m▄\e[48;2;255;102;0m\e[38;2;255;102;0m▄\e[48;2;189;86;16m\e[38;2;255;104;0m▄\e[48;2;102;68;44m\e[38;2;250;100;0m▄\e[48;2;68;61;55m\e[38;2;165;80;24m▄\e[48;2;67;61;57m\e[38;2;89;65;48m▄\e[48;2;73;62;55m\e[38;2;72;62;56m▄\e[48;2;71;61;54m\e[38;2;72;61;54m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;48;42;37m\e[38;2;66;57;50m▄\e[48;2;24;22;20m\e[38;2;31;27;25m▄\e[0m $(:                                                                               )
 \e[48;2;24;22;20m\e[38;2;27;24;22m▄\e[48;2;45;40;35m\e[38;2;61;52;46m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;71;61;54m\e[38;2;71;61;54m▄\e[48;2;72;62;55m\e[38;2;71;62;55m▄\e[48;2;71;61;56m\e[38;2;75;62;55m▄\e[48;2;173;84;25m\e[38;2;181;86;23m▄\e[48;2;255;107;0m\e[38;2;251;103;1m▄\e[48;2;253;102;0m\e[38;2;251;101;1m▄\e[48;2;254;102;0m\e[38;2;255;102;0m▄\e[48;2;255;102;0m\e[38;2;255;102;0m▄\e[48;2;255;102;0m\e[38;2;255;102;0m▄\e[48;2;254;102;0m\e[38;2;255;103;0m▄\e[48;2;253;101;0m\e[38;2;255;104;0m▄\e[48;2;255;105;0m\e[38;2;191;83;12m▄\e[48;2;249;101;1m\e[38;2;96;54;28m▄\e[48;2;165;74;15m\e[38;2;51;45;43m▄\e[48;2;76;49;34m\e[38;2;60;55;53m▄\e[48;2;47;47;49m\e[38;2;77;64;55m▄\e[48;2;70;59;52m\e[38;2;73;63;55m▄\e[48;2;75;64;56m\e[38;2;72;62;55m▄\e[48;2;61;60;59m\e[38;2;76;63;54m▄\e[48;2;92;65;46m\e[38;2;67;62;57m▄\e[48;2;170;81;23m\e[38;2;64;60;56m▄\e[48;2;244;98;1m\e[38;2;108;69;43m▄\e[48;2;255;105;0m\e[38;2;186;85;17m▄\e[48;2;254;102;1m\e[38;2;255;103;0m▄\e[48;2;254;102;0m\e[38;2;255;103;0m▄\e[48;2;255;102;0m\e[38;2;255;102;0m▄\e[48;2;255;102;0m\e[38;2;254;102;0m▄\e[48;2;254;102;0m\e[38;2;255;102;0m▄\e[48;2;253;102;1m\e[38;2;251;101;1m▄\e[48;2;255;107;0m\e[38;2;252;106;1m▄\e[48;2;165;76;18m\e[38;2;172;77;15m▄\e[48;2;64;55;50m\e[38;2;61;49;43m▄\e[48;2;72;62;55m\e[38;2;71;62;55m▄\e[48;2;72;61;54m\e[38;2;72;61;54m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;44;39;35m\e[38;2;61;52;46m▄\e[48;2;24;22;20m\e[38;2;26;24;21m▄\e[0m$(:               )
 \e[48;2;32;29;26m\e[38;2;44;38;34m▄\e[48;2;71;61;54m\e[38;2;72;62;55m▄\e[48;2;71;61;54m\e[38;2;71;61;54m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;71;62;55m\e[38;2;71;62;55m▄\e[48;2;74;62;55m\e[38;2;74;62;55m▄\e[48;2;179;86;23m\e[38;2;180;86;23m▄\e[48;2;255;104;0m\e[38;2;255;104;0m▄\e[48;2;252;101;1m\e[38;2;252;101;1m▄\e[48;2;255;102;0m\e[38;2;253;101;0m▄\e[48;2;253;101;0m\e[38;2;255;105;0m▄\e[48;2;254;103;0m\e[38;2;213;90;8m▄\e[48;2;224;92;5m\e[38;2;65;46;36m▄\e[48;2;116;60;26m\e[38;2;54;49;47m▄\e[48;2;58;46;39m\e[38;2;69;61;54m▄\e[48;2;56;52;51m\e[38;2;75;63;55m▄\e[48;2;74;62;54m\e[38;2;73;62;55m▄\e[48;2;76;64;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;73;62;55m\e[38;2;69;61;56m▄\e[48;2;72;62;55m\e[38;2;75;63;54m▄\e[48;2;74;62;54m\e[38;2;72;62;55m▄\e[48;2;74;63;55m\e[38;2;72;62;55m▄\e[48;2;64;60;58m\e[38;2;74;62;54m▄\e[48;2;74;62;54m\e[38;2;71;62;56m▄\e[48;2;122;71;37m\e[38;2;67;61;56m▄\e[48;2;217;92;8m\e[38;2;77;62;52m▄\e[48;2;255;104;0m\e[38;2;154;77;27m▄\e[48;2;255;103;0m\e[38;2;234;96;5m▄\e[48;2;254;102;0m\e[38;2;255;103;0m▄\e[48;2;251;101;1m\e[38;2;254;102;0m▄\e[48;2;255;106;0m\e[38;2;252;105;1m▄\e[48;2;170;77;15m\e[38;2;171;77;15m▄\e[48;2;61;50;44m\e[38;2;61;50;44m▄\e[48;2;71;62;55m\e[38;2;71;62;55m▄\e[48;2;73;62;55m\e[38;2;73;62;55m▄\e[48;2;71;61;54m\e[38;2;71;61;54m▄\e[48;2;70;61;54m\e[38;2;72;62;55m▄\e[48;2;32;29;25m\e[38;2;43;38;33m▄\e[0m$(:                               )
 \e[48;2;53;46;42m\e[38;2;61;53;46m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;71;61;54m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;71;62;55m\e[38;2;71;62;55m▄\e[48;2;74;62;55m\e[38;2;74;62;55m▄\e[48;2;180;86;23m\e[38;2;180;86;23m▄\e[48;2;255;104;0m\e[38;2;255;104;0m▄\e[48;2;252;101;1m\e[38;2;252;101;1m▄\e[48;2;252;101;0m\e[38;2;252;101;0m▄\e[48;2;255;106;0m\e[38;2;255;106;0m▄\e[48;2;203;86;8m\e[38;2;204;86;8m▄\e[48;2;56;47;43m\e[38;2;58;47;42m▄\e[48;2;72;62;55m\e[38;2;71;61;54m▄\e[48;2;74;63;55m\e[38;2;73;63;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;70;62;55m▄\e[48;2;74;62;54m\e[38;2;77;63;53m▄\e[48;2;86;65;51m\e[38;2;208;92;14m▄\e[48;2;60;60;59m\e[38;2;135;75;34m▄\e[48;2;74;63;55m\e[38;2;69;60;55m▄\e[48;2;74;62;54m\e[38;2;66;61;58m▄\e[48;2;72;62;55m\e[38;2;74;62;54m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;73;62;55m\e[38;2;72;62;55m▄\e[48;2;71;62;56m\e[38;2;72;62;55m▄\e[48;2;62;60;58m\e[38;2;74;62;54m▄\e[48;2;88;63;47m\e[38;2;69;62;57m▄\e[48;2;179;83;20m\e[38;2;63;59;57m▄\e[48;2;243;97;2m\e[38;2;116;69;39m▄\e[48;2;255;108;0m\e[38;2;200;91;15m▄\e[48;2;171;77;16m\e[38;2;168;75;13m▄\e[48;2;61;50;44m\e[38;2;62;50;43m▄\e[48;2;71;62;55m\e[38;2;70;62;56m▄\e[48;2;73;62;55m\e[38;2;73;62;55m▄\e[48;2;71;61;54m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;53;46;41m\e[38;2;60;52;47m▄\e[0m$(:                                     )
 \e[48;2;65;57;50m\e[38;2;68;59;51m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;71;62;55m\e[38;2;71;62;55m▄\e[48;2;74;62;55m\e[38;2;74;62;55m▄\e[48;2;180;86;23m\e[38;2;180;86;23m▄\e[48;2;255;104;0m\e[38;2;255;104;0m▄\e[48;2;252;101;1m\e[38;2;252;101;1m▄\e[48;2;252;101;0m\e[38;2;252;101;0m▄\e[48;2;255;106;0m\e[38;2;255;106;0m▄\e[48;2;204;86;8m\e[38;2;204;86;8m▄\e[48;2;58;47;42m\e[38;2;58;47;42m▄\e[48;2;71;61;54m\e[38;2;71;61;54m▄\e[48;2;73;63;55m\e[38;2;73;63;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;70;62;56m\e[38;2;70;62;56m▄\e[48;2;76;63;54m\e[38;2;76;63;54m▄\e[48;2;255;103;0m\e[38;2;248;100;2m▄\e[48;2;253;101;0m\e[38;2;255;103;0m▄\e[48;2;195;87;15m\e[38;2;255;104;0m▄\e[48;2;106;68;42m\e[38;2;241;99;3m▄\e[48;2;64;60;57m\e[38;2;175;82;20m▄\e[48;2;70;62;56m\e[38;2;85;63;49m▄\e[48;2;72;62;55m\e[38;2;67;61;57m▄\e[48;2;73;62;55m\e[38;2;68;61;56m▄\e[48;2;72;62;55m\e[38;2;74;62;54m▄\e[48;2;73;62;54m\e[38;2;73;62;55m▄\e[48;2;75;63;54m\e[38;2;72;62;55m▄\e[48;2;61;60;59m\e[38;2;75;63;54m▄\e[48;2;80;63;52m\e[38;2;70;62;56m▄\e[48;2;94;62;41m\e[38;2;67;61;57m▄\e[48;2;65;52;47m\e[38;2;71;61;55m▄\e[48;2;71;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;66;56;49m\e[38;2;68;58;51m▄\e[0m$(:                                     )
 \e[48;2;68;59;51m\e[38;2;65;57;50m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;71;62;55m\e[38;2;71;62;55m▄\e[48;2;74;62;55m\e[38;2;74;62;55m▄\e[48;2;180;86;23m\e[38;2;180;86;23m▄\e[48;2;255;104;0m\e[38;2;255;104;0m▄\e[48;2;252;101;1m\e[38;2;252;101;1m▄\e[48;2;252;101;0m\e[38;2;252;101;0m▄\e[48;2;255;106;0m\e[38;2;255;106;0m▄\e[48;2;204;86;8m\e[38;2;204;86;8m▄\e[48;2;58;47;42m\e[38;2;58;47;42m▄\e[48;2;71;61;54m\e[38;2;71;61;54m▄\e[48;2;73;63;55m\e[38;2;73;63;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;70;62;56m\e[38;2;70;62;56m▄\e[48;2;76;63;54m\e[38;2;76;63;54m▄\e[48;2;251;101;1m\e[38;2;248;100;2m▄\e[48;2;254;102;0m\e[38;2;254;102;0m▄\e[48;2;253;102;1m\e[38;2;255;102;0m▄\e[48;2;255;103;0m\e[38;2;254;102;0m▄\e[48;2;255;103;0m\e[38;2;255;102;0m▄\e[48;2;238;97;3m\e[38;2;255;103;0m▄\e[48;2;145;74;29m\e[38;2;255;103;0m▄\e[48;2;80;63;52m\e[38;2;211;90;10m▄\e[48;2;65;60;57m\e[38;2;124;72;36m▄\e[48;2;72;62;55m\e[38;2;70;61;54m▄\e[48;2;75;62;54m\e[38;2;65;61;58m▄\e[48;2;72;62;55m\e[38;2;76;63;54m▄\e[48;2;73;62;55m\e[38;2;73;62;55m▄\e[48;2;73;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;68;58;51m\e[38;2;66;56;49m▄\e[0m$(:                              )
 \e[48;2;61;53;46m\e[38;2;53;46;42m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;71;61;54m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;71;62;55m\e[38;2;71;62;55m▄\e[48;2;74;62;55m\e[38;2;74;62;55m▄\e[48;2;180;86;23m\e[38;2;180;86;23m▄\e[48;2;255;104;0m\e[38;2;255;104;0m▄\e[48;2;252;101;1m\e[38;2;252;101;1m▄\e[48;2;252;101;0m\e[38;2;252;101;0m▄\e[48;2;255;106;0m\e[38;2;255;106;0m▄\e[48;2;204;86;8m\e[38;2;203;86;8m▄\e[48;2;58;47;42m\e[38;2;56;46;42m▄\e[48;2;71;61;54m\e[38;2;72;61;54m▄\e[48;2;73;63;55m\e[38;2;74;63;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;70;62;56m\e[38;2;71;62;55m▄\e[48;2;77;63;54m\e[38;2;72;62;55m▄\e[48;2;255;103;0m\e[38;2;147;77;31m▄\e[48;2;255;103;0m\e[38;2;234;96;3m▄\e[48;2;254;101;0m\e[38;2;255;105;0m▄\e[48;2;255;102;0m\e[38;2;255;102;0m▄\e[48;2;255;102;0m\e[38;2;254;102;0m▄\e[48;2;255;102;0m\e[38;2;255;102;0m▄\e[48;2;253;102;0m\e[38;2;255;102;0m▄\e[48;2;255;104;0m\e[38;2;253;101;0m▄\e[48;2;254;100;0m\e[38;2;254;102;1m▄\e[48;2;187;86;18m\e[38;2;255;105;0m▄\e[48;2;104;68;42m\e[38;2;233;97;4m▄\e[48;2;59;59;58m\e[38;2;169;81;23m▄\e[48;2;71;62;56m\e[38;2;83;63;49m▄\e[48;2;73;62;54m\e[38;2;65;61;58m▄\e[48;2;72;62;55m\e[38;2;74;62;54m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;71;61;54m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;60;52;47m\e[38;2;53;46;41m▄\e[0m$(:                        )
 \e[48;2;44;38;34m\e[38;2;32;29;26m▄\e[48;2;72;62;55m\e[38;2;71;61;54m▄\e[48;2;71;61;54m\e[38;2;71;61;54m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;71;62;55m\e[38;2;71;62;55m▄\e[48;2;74;62;55m\e[38;2;74;62;55m▄\e[48;2;180;86;23m\e[38;2;179;86;23m▄\e[48;2;255;104;0m\e[38;2;255;104;0m▄\e[48;2;252;101;1m\e[38;2;252;101;1m▄\e[48;2;253;101;0m\e[38;2;255;102;0m▄\e[48;2;255;105;0m\e[38;2;253;102;0m▄\e[48;2;213;89;7m\e[38;2;254;103;0m▄\e[48;2;71;51;39m\e[38;2;228;94;5m▄\e[48;2;65;59;55m\e[38;2;132;73;34m▄\e[48;2;71;63;56m\e[38;2;76;62;53m▄\e[48;2;74;63;54m\e[38;2;63;60;58m▄\e[48;2;73;62;55m\e[38;2;73;62;55m▄\e[48;2;72;62;55m\e[38;2;74;62;54m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;66;60;57m\e[38;2;73;62;55m▄\e[48;2;93;65;47m\e[38;2;68;61;56m▄\e[48;2;173;82;20m\e[38;2;69;62;56m▄\e[48;2;250;100;0m\e[38;2;104;67;42m▄\e[48;2;255;103;0m\e[38;2;192;86;15m▄\e[48;2;255;102;0m\e[38;2;248;101;2m▄\e[48;2;255;102;0m\e[38;2;255;102;0m▄\e[48;2;255;102;0m\e[38;2;255;102;0m▄\e[48;2;254;102;0m\e[38;2;255;102;0m▄\e[48;2;252;101;1m\e[38;2;255;102;0m▄\e[48;2;255;104;0m\e[38;2;253;102;0m▄\e[48;2;255;103;0m\e[38;2;251;101;1m▄\e[48;2;229;95;6m\e[38;2;255;107;0m▄\e[48;2;124;71;36m\e[38;2;172;77;14m▄\e[48;2;68;60;55m\e[38;2;62;51;45m▄\e[48;2;73;62;55m\e[38;2;71;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;71;61;54m\e[38;2;71;61;54m▄\e[48;2;72;62;55m\e[38;2;70;61;54m▄\e[48;2;43;38;34m\e[38;2;32;29;25m▄\e[0m$(:                     )
 \e[48;2;26;24;21m\e[38;2;24;22;20m▄\e[48;2;61;52;46m\e[38;2;45;39;35m▄\e[48;2;72;62;55m\e[38;2;72;61;55m▄\e[48;2;71;61;54m\e[38;2;71;61;54m▄\e[48;2;71;62;55m\e[38;2;72;62;55m▄\e[48;2;75;62;55m\e[38;2;71;61;56m▄\e[48;2;181;86;23m\e[38;2;173;84;24m▄\e[48;2;251;103;1m\e[38;2;255;107;0m▄\e[48;2;251;101;1m\e[38;2;254;102;1m▄\e[48;2;255;102;0m\e[38;2;254;102;0m▄\e[48;2;255;102;0m\e[38;2;255;102;0m▄\e[48;2;255;102;0m\e[38;2;255;102;0m▄\e[48;2;255;103;0m\e[38;2;255;102;0m▄\e[48;2;255;103;0m\e[38;2;253;102;1m▄\e[48;2;197;86;14m\e[38;2;255;105;0m▄\e[48;2;118;70;40m\e[38;2;253;101;0m▄\e[48;2;71;61;55m\e[38;2;183;84;19m▄\e[48;2;65;61;58m\e[38;2;101;66;44m▄\e[48;2;76;63;54m\e[38;2;60;59;58m▄\e[48;2;73;62;55m\e[38;2;72;62;56m▄\e[48;2;73;62;55m\e[38;2;72;62;55m▄\e[48;2;76;63;54m\e[38;2;61;59;58m▄\e[48;2;65;60;57m\e[38;2;102;68;46m▄\e[48;2;61;60;59m\e[38;2;177;84;24m▄\e[48;2;111;70;42m\e[38;2;248;100;2m▄\e[48;2;232;97;6m\e[38;2;255;103;0m▄\e[48;2;255;103;0m\e[38;2;255;102;0m▄\e[48;2;254;102;0m\e[38;2;255;102;0m▄\e[48;2;255;102;0m\e[38;2;255;102;0m▄\e[48;2;255;102;0m\e[38;2;255;102;0m▄\e[48;2;255;102;0m\e[38;2;254;102;0m▄\e[48;2;251;101;1m\e[38;2;252;101;1m▄\e[48;2;250;105;1m\e[38;2;255;109;0m▄\e[48;2;172;77;15m\e[38;2;163;75;16m▄\e[48;2;62;50;44m\e[38;2;57;48;44m▄\e[48;2;71;62;55m\e[38;2;72;62;55m▄\e[48;2;72;61;54m\e[38;2;71;61;54m▄\e[48;2;72;62;55m\e[38;2;71;62;55m▄\e[48;2;60;52;46m\e[38;2;45;39;35m▄\e[48;2;26;24;21m\e[38;2;24;22;20m▄\e[0m$(:            )
  \e[48;2;31;28;25m\e[38;2;24;22;20m▄\e[48;2;66;57;51m\e[38;2;49;42;38m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;71;61;54m\e[38;2;71;61;54m▄\e[48;2;71;62;55m\e[38;2;73;62;55m▄\e[48;2;92;67;50m\e[38;2;67;61;57m▄\e[48;2;159;79;26m\e[38;2;67;60;56m▄\e[48;2;245;99;0m\e[38;2;100;67;44m▄\e[48;2;255;104;0m\e[38;2;189;86;16m▄\e[48;2;255;102;0m\e[38;2;254;102;0m▄\e[48;2;254;102;0m\e[38;2;255;103;0m▄\e[48;2;255;102;0m\e[38;2;255;102;0m▄\e[48;2;255;102;0m\e[38;2;253;101;0m▄\e[48;2;252;101;1m\e[38;2;255;102;0m▄\e[48;2;254;102;1m\e[38;2;254;102;0m▄\e[48;2;255;104;0m\e[38;2;252;101;1m▄\e[48;2;232;97;5m\e[38;2;255;104;0m▄\e[48;2;169;81;23m\e[38;2;255;103;0m▄\e[48;2;82;63;50m\e[38;2;227;95;8m▄\e[48;2;80;63;52m\e[38;2;227;95;8m▄\e[48;2;164;82;27m\e[38;2;255;103;0m▄\e[48;2;232;98;7m\e[38;2;255;103;0m▄\e[48;2;255;104;0m\e[38;2;251;101;1m▄\e[48;2;255;102;0m\e[38;2;254;102;0m▄\e[48;2;254;102;0m\e[38;2;255;102;0m▄\e[48;2;255;102;0m\e[38;2;253;101;0m▄\e[48;2;255;102;0m\e[38;2;255;102;0m▄\e[48;2;254;102;0m\e[38;2;255;104;0m▄\e[48;2;255;102;0m\e[38;2;255;103;0m▄\e[48;2;255;105;0m\e[38;2;184;81;13m▄\e[48;2;250;101;1m\e[38;2;85;52;31m▄\e[48;2;157;72;17m\e[38;2;53;46;44m▄\e[48;2;72;48;34m\e[38;2;62;57;53m▄\e[48;2;64;54;49m\e[38;2;73;62;55m▄\e[48;2;72;61;54m\e[38;2;71;61;54m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;66;57;50m\e[38;2;48;42;37m▄\e[48;2;31;28;25m\e[38;2;24;22;20m▄\e[0m $(:                                                                                 )
   \e[48;2;29;26;24m\e[38;2;24;22;20m▄\e[48;2;64;55;49m\e[38;2;39;35;31m▄\e[48;2;72;62;55m\e[38;2;71;61;54m▄\e[48;2;71;61;54m\e[38;2;71;61;54m▄\e[48;2;73;62;55m\e[38;2;72;62;55m▄\e[48;2;73;62;55m\e[38;2;72;62;55m▄\e[48;2;67;61;57m\e[38;2;73;62;55m▄\e[48;2;69;61;56m\e[38;2;72;62;55m▄\e[48;2;120;70;37m\e[38;2;66;61;57m▄\e[48;2;215;92;10m\e[38;2;70;61;54m▄\e[48;2;254;102;0m\e[38;2;148;76;29m▄\e[48;2;255;104;0m\e[38;2;223;94;7m▄\e[48;2;252;101;1m\e[38;2;255;104;0m▄\e[48;2;254;102;0m\e[38;2;255;103;0m▄\e[48;2;255;102;0m\e[38;2;252;101;1m▄\e[48;2;253;101;0m\e[38;2;255;102;0m▄\e[48;2;254;102;0m\e[38;2;255;102;0m▄\e[48;2;255;103;0m\e[38;2;254;102;0m▄\e[48;2;255;103;0m\e[38;2;254;102;0m▄\e[48;2;255;102;0m\e[38;2;255;102;0m▄\e[48;2;253;102;0m\e[38;2;255;102;0m▄\e[48;2;255;102;0m\e[38;2;252;101;0m▄\e[48;2;254;102;0m\e[38;2;255;102;0m▄\e[48;2;251;101;1m\e[38;2;255;106;0m▄\e[48;2;255;104;0m\e[38;2;226;94;5m▄\e[48;2;255;104;0m\e[38;2;145;69;19m▄\e[48;2;216;89;7m\e[38;2;57;45;39m▄\e[48;2;113;59;25m\e[38;2;53;49;48m▄\e[48;2;51;44;41m\e[38;2;73;62;55m▄\e[48;2;58;54;51m\e[38;2;74;63;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;74;63;55m\e[38;2;72;62;55m▄\e[48;2;71;61;54m\e[38;2;71;61;54m▄\e[48;2;72;62;55m\e[38;2;71;61;54m▄\e[48;2;63;55;49m\e[38;2;38;34;31m▄\e[48;2;28;26;23m\e[38;2;24;22;20m▄\e[0m  $(:                                                                                                                                                              )
     \e[48;2;48;42;37m\e[38;2;25;23;20m▄\e[48;2;71;62;54m\e[38;2;53;45;41m▄\e[48;2;71;61;54m\e[38;2;71;61;54m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;73;62;55m\e[38;2;72;62;55m▄\e[48;2;74;62;55m\e[38;2;72;62;55m▄\e[48;2;60;59;59m\e[38;2;75;63;54m▄\e[48;2;90;64;47m\e[38;2;68;62;57m▄\e[48;2;169;81;23m\e[38;2;64;59;56m▄\e[48;2;243;98;1m\e[38;2;109;68;41m▄\e[48;2;255;105;0m\e[38;2;187;85;17m▄\e[48;2;253;102;0m\e[38;2;255;102;0m▄\e[48;2;254;102;0m\e[38;2;255;103;0m▄\e[48;2;255;102;0m\e[38;2;255;102;0m▄\e[48;2;255;102;0m\e[38;2;255;102;0m▄\e[48;2;254;102;0m\e[38;2;255;103;0m▄\e[48;2;253;101;0m\e[38;2;255;104;0m▄\e[48;2;255;105;0m\e[38;2;191;84;11m▄\e[48;2;247;100;2m\e[38;2;97;54;29m▄\e[48;2;166;75;16m\e[38;2;49;45;44m▄\e[48;2;80;50;33m\e[38;2;61;55;52m▄\e[48;2;45;46;48m\e[38;2;77;64;55m▄\e[48;2;70;60;53m\e[38;2;73;63;55m▄\e[48;2;75;64;56m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;71;61;54m\e[38;2;71;61;54m▄\e[48;2;72;61;54m\e[38;2;52;46;40m▄\e[48;2;48;42;37m\e[38;2;24;22;20m▄\e[0m    $(:                                                                                                                                                                                                                                                                                                                   )
      \e[48;2;25;22;20m\e[38;2;24;22;20m▄\e[48;2;52;44;40m\e[38;2;24;22;20m▄\e[48;2;72;62;54m\e[38;2;48;42;37m▄\e[48;2;72;62;55m\e[38;2;70;60;54m▄\e[48;2;71;61;54m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;71;61;54m▄\e[48;2;72;62;55m\e[38;2;71;61;54m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;74;62;54m\e[38;2;72;62;55m▄\e[48;2;74;63;55m\e[38;2;72;62;55m▄\e[48;2;64;60;58m\e[38;2;74;62;54m▄\e[48;2;73;61;54m\e[38;2;70;62;56m▄\e[48;2;122;71;36m\e[38;2;67;61;56m▄\e[48;2;221;92;8m\e[38;2;78;62;53m▄\e[48;2;255;102;0m\e[38;2;157;79;26m▄\e[48;2;255;103;0m\e[38;2;151;72;21m▄\e[48;2;225;93;5m\e[38;2;59;44;38m▄\e[48;2;118;60;25m\e[38;2;56;50;48m▄\e[48;2;58;45;40m\e[38;2;69;60;55m▄\e[48;2;57;53;51m\e[38;2;75;63;55m▄\e[48;2;72;62;54m\e[38;2;73;62;55m▄\e[48;2;76;64;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;71;61;54m▄\e[48;2;72;62;55m\e[38;2;71;61;54m▄\e[48;2;71;61;54m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;70;60;53m▄\e[48;2;71;61;54m\e[38;2;48;42;37m▄\e[48;2;52;46;41m\e[38;2;24;22;20m▄\e[48;2;25;23;21m\e[38;2;24;22;20m▄\e[0m     $(:                                                                                                                                                                                                                                                                                                                                                                                                     )
         \e[48;2;40;35;31m\e[38;2;24;22;20m▄\e[48;2;63;54;48m\e[38;2;28;25;23m▄\e[48;2;72;62;55m\e[38;2;48;42;37m▄\e[48;2;72;62;55m\e[38;2;66;57;51m▄\e[48;2;71;61;54m\e[38;2;72;62;55m▄\e[48;2;71;61;54m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;71;61;54m▄\e[48;2;72;62;55m\e[38;2;71;61;54m▄\e[48;2;73;62;55m\e[38;2;72;62;55m▄\e[48;2;73;62;55m\e[38;2;72;62;55m▄\e[48;2;71;62;56m\e[38;2;72;62;55m▄\e[48;2;65;61;57m\e[38;2;73;62;55m▄\e[48;2;62;57;55m\e[38;2;74;63;55m▄\e[48;2;66;58;53m\e[38;2;73;62;55m▄\e[48;2;73;64;56m\e[38;2;72;62;55m▄\e[48;2;73;62;55m\e[38;2;72;62;55m▄\e[48;2;72;62;55m\e[38;2;71;61;54m▄\e[48;2;72;62;55m\e[38;2;71;61;54m▄\e[48;2;71;61;54m\e[38;2;72;62;55m▄\e[48;2;71;61;54m\e[38;2;71;61;55m▄\e[48;2;72;62;55m\e[38;2;66;57;51m▄\e[48;2;72;62;55m\e[38;2;49;43;37m▄\e[48;2;64;55;49m\e[38;2;30;27;24m▄\e[48;2;39;35;31m\e[38;2;24;22;20m▄\e[0m        $(:                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       )
            \e[48;2;31;28;26m\e[38;2;24;22;20m▄\e[48;2;45;39;35m\e[38;2;24;22;20m▄\e[48;2;60;52;46m\e[38;2;27;24;22m▄\e[48;2;71;62;55m\e[38;2;32;28;25m▄\e[48;2;72;62;55m\e[38;2;43;38;33m▄\e[48;2;72;62;55m\e[38;2;53;47;41m▄\e[48;2;72;62;55m\e[38;2;61;52;46m▄\e[48;2;72;62;55m\e[38;2;65;57;50m▄\e[48;2;72;62;55m\e[38;2;68;59;51m▄\e[48;2;72;62;55m\e[38;2;68;59;51m▄\e[48;2;72;62;55m\e[38;2;65;57;50m▄\e[48;2;72;62;55m\e[38;2;60;52;46m▄\e[48;2;72;62;55m\e[38;2;53;46;41m▄\e[48;2;72;62;55m\e[38;2;43;37;33m▄\e[48;2;71;62;55m\e[38;2;32;28;25m▄\e[48;2;59;51;46m\e[38;2;27;24;22m▄\e[48;2;44;39;34m\e[38;2;24;22;20m▄\e[48;2;31;28;25m\e[38;2;24;22;20m▄\e[0m           $(:                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   )"

EOF
    "$1/logo.bash" >"$1/logo.ansi"

    sys::Write <<'EOF' "$1/logo-min.bash" 0:0 755
#!/bin/bash
echo -e "
 \e[33m      ▁▄▆█▆▄▁      \e[0m$(:                              )
 \e[33m   ▂▅▇███████▇▅▂   \e[0m$(:                              )
 \e[33m▄▆█████\e[7m▁▄▅▄▁\e[27m████▆▄ \e[0m$(:                   )
 \e[33m████\e[7m▂▅▇\e[27m     \e[7m▇▅▂\e[27m████\e[0m$(:        )
 \e[33m███▉     ▗▃     \e[7m▆▃▁\e[27m\e[0m$(:                   )
 \e[33m███▉     ▐██▆▄▂    \e[0m$(:                              )
 \e[33m███▉     ▝█████▇▅▃ \e[0m$(:                              )
 \e[33m████▆▃▁    \e[7m▆\e[27m▜██████\e[0m$(:                   )
 \e[33m\e[7m▄▂\e[27m█████▇▅▃▅▇█████\e[7m▂▄\e[27m\e[0m$(:        )
 \e[33m   \e[7m▅▃▁\e[27m███████\e[7m▁▃▅\e[27m   \e[0m$(:        )
 \e[33m      \e[7m▇\e[27m▀\e[7m▂\e[27m█\e[7m▂▄▆\e[27m      \e[0m"
EOF
    "$1/logo-min.bash" >"$1/logo-min.ansi"


    sys::Write <<EOF "$1/logo.svg"
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg
   xmlns:dc="http://purl.org/dc/elements/1.1/"
   xmlns:cc="http://creativecommons.org/ns#"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   xmlns:svg="http://www.w3.org/2000/svg"
   xmlns="http://www.w3.org/2000/svg"
   xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"
   xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
   viewBox="0 0 48 48"
   version="1.1"
   id="svg1643"
   sodipodi:docname="logo2bf_NEW.svg"
   inkscape:version="0.92.2 (unknown)">
  <metadata
     id="metadata1647">
    <rdf:RDF>
      <cc:Work
         rdf:about="">
        <dc:format>image/svg+xml</dc:format>
        <dc:type
           rdf:resource="http://purl.org/dc/dcmitype/StillImage" />
        <dc:title></dc:title>
      </cc:Work>
    </rdf:RDF>
  </metadata>
  <sodipodi:namedview
     pagecolor="#ffffff"
     bordercolor="#666666"
     borderopacity="1"
     objecttolerance="10"
     gridtolerance="10"
     guidetolerance="10"
     inkscape:pageopacity="0"
     inkscape:pageshadow="2"
     inkscape:window-width="1680"
     inkscape:window-height="1016"
     id="namedview1645"
     showgrid="true"
     inkscape:zoom="16"
     inkscape:cx="22.304259"
     inkscape:cy="24.034594"
     inkscape:window-x="0"
     inkscape:window-y="34"
     inkscape:window-maximized="1"
     inkscape:current-layer="svg1643">
    <inkscape:grid
       type="axonomgrid"
       id="grid12"
       units="mm"
       empspacing="6"
       snapvisiblegridlinesonly="false"
       originx="4.1574803"
       originy="-13.606299"
       enabled="false" />
  </sodipodi:namedview>
  <circle
     style="fill:#$THEME_COLOR_OBJECT_HEX;fill-opacity:1;stroke:none;stroke-width:0.1;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
     id="path4418-6"
     cx="24"
     cy="24"
     r="23.938484" />
  <g
     id="g1520">
    <path
       style="fill:#$THEME_COLOR_WINDOW_HEX;stroke:none;stroke-width:0.09704073px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1;fill-opacity:0.60000002"
       d="M 25.201308,5.7962793 8.8354753,15.245094 V 34.142733 L 25.201308,43.591552 41.567143,34.142733 V 30.363206 L 25.201308,20.914387 v 7.559055 l 6.546334,3.779528 -6.546334,3.657944 -9.819499,-5.547708 V 19.024623 l 9.819499,-5.669293 16.365835,9.448821 v -7.559057 z"
       id="path904-3-3"
       inkscape:connector-curvature="0"
       sodipodi:nodetypes="cccccccccccccccc" />
    <path
       style="fill:#$THEME_COLOR_HOTHOT_HEX;stroke:none;stroke-width:0.09704073px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
       d="M 23.999999,5.1023623 7.6341657,14.551181 V 33.448819 L 23.999999,42.897638 40.365834,33.448819 V 29.669292 L 23.999999,20.220473 v 7.559055 l 6.546334,3.779528 -6.546334,3.657944 -9.8195,-5.547708 V 18.330709 l 9.8195,-5.669292 16.365835,9.44882 v -7.559056 z"
       id="path904-3"
       inkscape:connector-curvature="0"
       sodipodi:nodetypes="cccccccccccccccc" />
  </g>
</svg>
EOF

    sys::Write <<EOF "$1/title.svg"
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!-- Created with Inkscape (http://www.inkscape.org/) -->

<svg
   xmlns:dc="http://purl.org/dc/elements/1.1/"
   xmlns:cc="http://creativecommons.org/ns#"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   xmlns:svg="http://www.w3.org/2000/svg"
   xmlns="http://www.w3.org/2000/svg"
   xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"
   xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
   width="42.928371mm"
   height="8.6766586mm"
   viewBox="0 0 42.928371 8.6766586"
   version="1.1"
   id="svg6512"
   inkscape:version="0.92.2 (unknown)"
   sodipodi:docname="title.svg">
  <defs
     id="defs6506" />
  <sodipodi:namedview
     id="base"
     pagecolor="#ffffff"
     bordercolor="#666666"
     borderopacity="1.0"
     inkscape:pageopacity="0.0"
     inkscape:pageshadow="2"
     inkscape:zoom="0.98994949"
     inkscape:cx="-18.921601"
     inkscape:cy="71.239829"
     inkscape:document-units="mm"
     inkscape:current-layer="layer1"
     showgrid="false"
     fit-margin-top="0"
     fit-margin-left="0"
     fit-margin-right="0"
     fit-margin-bottom="0"
     showborder="false"
     inkscape:window-width="1680"
     inkscape:window-height="1016"
     inkscape:window-x="0"
     inkscape:window-y="34"
     inkscape:window-maximized="1" />
  <metadata
     id="metadata6509">
    <rdf:RDF>
      <cc:Work
         rdf:about="">
        <dc:format>image/svg+xml</dc:format>
        <dc:type
           rdf:resource="http://purl.org/dc/dcmitype/StillImage" />
        <dc:title></dc:title>
      </cc:Work>
    </rdf:RDF>
  </metadata>
  <g
     inkscape:label="Layer 1"
     inkscape:groupmode="layer"
     id="layer1"
     transform="translate(-85.125099,-69.655705)">
    <path
       sodipodi:nodetypes="cccccccccccccccc"
       inkscape:connector-curvature="0"
       id="path904-3"
       d="m 87.625102,69.672109 -2.500003,4.330128 2.5,4.330127 5.000003,-10e-7 2.499999,-4.330127 -0.5,-0.866025 -4.999999,-10e-7 1,1.732051 1.999996,2e-6 -1.016081,1.70419 -2.983919,0.02786 -1.5,-2.598076 1.500004,-2.598079 4.999999,1e-6 -1,-1.732051 z"
       style="fill:#$THEME_COLOR_HOTHOT_HEX;stroke:none;stroke-width:0.02567536px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
       inkscape:export-xdpi="355.01001"
       inkscape:export-ydpi="355.01001" />
    <path
       sodipodi:nodetypes="cccccccccccccccc"
       inkscape:connector-curvature="0"
       id="path904-3-6-2"
       d="m 109.55347,69.655732 -2.50001,4.330128 2.5,4.330127 5.00001,-1e-6 2.5,-4.330129 -0.5,-0.866024 -1,-1.732052 h -2 l 1.5,2.598076 -1.51609,2.57022 -2.98392,0.02786 -1.5,-2.598077 1.50001,-2.598078 5,-10e-7 -1,-1.732052 z"
       style="fill:#$THEME_COLOR_HOTHOT_HEX;stroke:none;stroke-width:0.02567536px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
       inkscape:export-xdpi="355.01001"
       inkscape:export-ydpi="355.01001" />
    <path
       sodipodi:nodetypes="cccccccccccccccc"
       inkscape:connector-curvature="0"
       id="path904-3-6-9"
       d="m 120.55347,69.655731 -2.5,4.330129 0.5,0.866025 3,-10e-7 h 4 l -1,1.732051 -5,10e-7 1,1.732051 5,-1e-6 2.5,-4.330129 -0.5,-0.866025 -7,10e-7 1,-1.732051 5,-10e-7 -1,-1.732051 z"
       style="fill:#$THEME_COLOR_HOTHOT_HEX;stroke:none;stroke-width:0.02567536px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
       inkscape:export-xdpi="355.01001"
       inkscape:export-ydpi="355.01001" />
    <path
       sodipodi:nodetypes="cccccccccccccccc"
       inkscape:connector-curvature="0"
       id="path904-3-6-23"
       d="m 103.05347,75.717908 -3.499999,-6.062178 -1.000004,2e-6 -2.500007,4.33013 2.500001,4.330128 2.000009,-7e-6 -1.500001,-2.598074 -0.967797,-1.732073 0.967843,-1.732055 3.499995,6.062177 1,3e-6 2.5,-4.330128 -2.5,-4.330127 -2,-10e-7 2.5,4.330127 z"
       style="fill:#$THEME_COLOR_HOTHOT_HEX;stroke:none;stroke-width:0.02567536px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
       inkscape:export-xdpi="355.01001"
       inkscape:export-ydpi="355.01001" />
  </g>
</svg>
EOF


}


BuildSublimeStyles ()
{

    # SUBLIME
    sys::Write <<EOF "$1/Afterglow-orange.sublime-theme"
[

    {
        "class" : "label_control",
        "font.size": 16,
        "font.face": "$THEME_FONT_SHORT_NAME",
        "color": [$THEME_COLOR_FOREGD_RGB],
    },


    // TABS

    {
        "class": "tab_label",
        "font.size": 11.49,
        "font.face": "$THEME_FONT_SHORT_NAME",
        "color": [$THEME_COLOR_FOREGD_RGB],
        "font.bold": true,
        "shadow_offset": [0, 0]
    },
    {
        "class": "tab_label",
        "attributes": ["dirty"],
        "color": [$THEME_COLOR_HOTHOT_RGB]
    },
    // - Preview tab
    {
        "class": "tab_label",
        "attributes": ["transient"],
        "font.italic": true,
        "font.bold": true,
    },
    //  - Tab element
    {
        "class": "tab_control",
        "content_margin": [8, 0, 0, 0],

       //  - Inactive tab settings
        "layer0.texture": "",
        "layer0.tint": [$THEME_COLOR_WINDOW_RGB],

        //  - Active tab setting
        "layer1.texture": "",
        "layer1.tint": [$THEME_COLOR_BACKGD_RGB],

        //  - Hover tab setting
        "layer2.texture": "",
        "layer2.tint": [$THEME_COLOR_OBJECT_RGB],
    },
    //  - Tabset
    {
        "class": "tabset_control",
        "layer0.texture": "",
        "layer0.tint": [$THEME_COLOR_WINDOW_RGB],
        "content_margin": [0, 0, 0, 0],
        "tab_height": 28,
        "mouse_wheel_switch": false,
    },


    // SIDEBAR

    // Sidebar container
    {
        "class": "sidebar_container",
        // "layer0.opacity": 1,
        "layer0.tint": [$THEME_COLOR_WINDOW_RGB],
        "content_margin": [2,0,0,0]
    },
    // Sidebar tree
    {
        "class": "sidebar_tree",
        "row_padding": [0,4],
    },
    // Sidebar entry
    {
        "class": "sidebar_label",
        "font.size": 16,
        "font.face": "$THEME_FONT_SHORT_NAME",
        "color": [200, 200, 200], // TODO templatize ?
    },
    {
        "class": "sidebar_label",
        "parents": [{"class": "tree_row","attributes": ["hover"]}],
        "color": [255, 255, 255] // TODO templatize ?
    },
    {
        "class": "sidebar_label",
        "parents": [{"class": "tree_row","attributes": ["selected"]}],
        "color": [255, 255, 255] // TODO templatize ?
    },
    {
        "class": "sidebar_label",
        "parents": [{"class": "tree_row","attributes": ["expandable"]}],
        "font.bold": true,
    },
    // TODO Dirty ?
    // {
    //     "class": "sidebar_label",
    //     "parents": [{"class": "close_button","attributes": ["dirty"]}],
    //     "parents": [{"class": "tree_row","attributes": ["dirty"]}],
    //     "attributes": ["dirty"],
    //     "color": [$THEME_COLOR_HOTHOT_RGB]
    // },
    // Sidebar rows
    {
        "class": "tree_row",
        "attributes": ["selected"],
        "layer0.tint": [$THEME_COLOR_SELECT_RGB],
    },



    // Bottom panel background
    {
        "class": "panel_control",
        "layer0.tint": [$THEME_COLOR_OBJECT_RGB],
    },


    // REFRESH BUG HERE
    // {
    //     "class": "icon_button_control",
    //     "attributes": ["selected"],
    //     "layer0.tint": [102,134,196], // 02
    //     "layer0.opacity": 0.1
    // },

    // Status bar container
    {
        "class": "status_bar",
        "layer0.tint": [$THEME_COLOR_WINDOW_RGB],
    },


    // Regex search button
    {
        "class": "icon_regex",
        "layer0.tint": [$THEME_COLOR_FOREGD_RGB]

    },
    {
        "class": "icon_regex",
        "parents": [{"class": "icon_button_control", "attributes": ["selected"]}],
        "layer0.tint": [$THEME_COLOR_HOTHOT_RGB]
    },
    // Case sensitive search button
    {
        "class": "icon_case",
        "layer0.tint": [$THEME_COLOR_FOREGD_RGB],
    },
    {
        "class": "icon_case",
        "parents": [{"class": "icon_button_control","attributes": ["selected"]}],
        "layer0.tint": [$THEME_COLOR_HOTHOT_RGB]
    },
    // Match whole word search button
    {
        "class": "icon_whole_word",
        "layer0.tint": [$THEME_COLOR_FOREGD_RGB],
    },
    {
        "class": "icon_whole_word",
        "parents": [{"class": "icon_button_control","attributes": ["selected"]}],
        "layer0.tint": [$THEME_COLOR_HOTHOT_RGB]
    },
    // Search wrap button
    {
        "class": "icon_wrap",
        "layer0.tint": [$THEME_COLOR_FOREGD_RGB],
    },
    {
        "class": "icon_wrap",
        "parents": [{"class": "icon_button_control","attributes": ["selected"]}],
        "layer0.tint": [$THEME_COLOR_HOTHOT_RGB]
    },
    // Search in selection button
    {
        "class": "icon_in_selection",
        "layer0.tint": [$THEME_COLOR_FOREGD_RGB],
    },
    {
        "class": "icon_in_selection",
        "parents": [{"class": "icon_button_control","attributes": ["selected"]}],
        "layer0.tint": [$THEME_COLOR_HOTHOT_RGB]
    },
    // Preserve case button
    {
        "class": "icon_preserve_case",
        "layer0.tint": [$THEME_COLOR_FOREGD_RGB],
    },
    {
        "class": "icon_preserve_case",
        "parents": [{"class": "icon_button_control","attributes": ["selected"]}],
        "layer0.tint": [$THEME_COLOR_HOTHOT_RGB]
    },
    // Highlight results button
    {
        "class": "icon_highlight",
        "layer0.tint": [$THEME_COLOR_FOREGD_RGB],
    },
    {
        "class": "icon_highlight",
        "parents": [{"class": "icon_button_control","attributes": ["selected"]}],
        "layer0.tint": [$THEME_COLOR_HOTHOT_RGB]
    },
    // Show search context button
    {
        "class": "icon_context",
        "layer0.tint": [$THEME_COLOR_FOREGD_RGB],
    },
    {
        "class": "icon_context",
        "parents": [{"class": "icon_button_control","attributes": ["selected"]}],
        "layer0.tint": [$THEME_COLOR_HOTHOT_RGB]
    },
    // Use search buffer
    {
        "class": "icon_use_buffer",
        "layer0.tint": [$THEME_COLOR_FOREGD_RGB],
    },
    {
        "class": "icon_use_buffer",
        "parents": [{"class": "icon_button_control","attributes": ["selected"]}],
        "layer0.tint": [$THEME_COLOR_HOTHOT_RGB]
    },

    //
    // QUICK PANEL
    //

    {
        "class": "quick_panel_row",
        "layer1.opacity": 0
    },

    { // DEV: CTRL-P
        "class": "quick_panel_row",
        "attributes": ["selected"],
        "layer1.opacity": 1,
        "layer1.tint": [$THEME_COLOR_SELECT_RGB],
    },

    {
        "class": "quick_panel_path_label",
        "selected_fg": [190, 190, 190, 255], // 03
    },

    //
    // MINI QUICK PANEL
    //

    { // DEV: CTRL-SHIFT-P
        "class": "mini_quick_panel_row",
        "attributes": ["selected"],
        "layer0.tint": [$THEME_COLOR_SELECT_RGB]
    },

    // Default button state
    {
        "class": "button_control",
        "layer0.tint": [$THEME_COLOR_BACKGD_RGB],
    },
    // Hover button state
    {
        "class": "button_control",
        "attributes": ["hover"],
        "layer0.tint": [$THEME_COLOR_SELECT_RGB],
    },


    // Text input field item
    {
        "class": "text_line_control",
        "layer0.tint": [$THEME_COLOR_BACKGD_RGB],
        "content_margin": [0, 0, 0, 0],
        "layer0.opacity": 1,
    },

    // Tooltip content
    {
        "class": "tool_tip_label_control",
        "font.size": 16,
        "font.face": "$THEME_FONT_SHORT_NAME",
        "color": [$THEME_COLOR_FOREGD_RGB],
    },

    // Scrollbars
    {
        "class": "scroll_bar_control",
        "layer0.tint": [$THEME_COLOR_BACKGD_RGB],
    },
    {
        "class": "scroll_corner_control",
        "layer0.tint": [$THEME_COLOR_BACKGD_RGB],
    },
    {
        "class": "puck_control",
        "layer0.tint": [$THEME_COLOR_SELECT_RGB],
    },
    {
        "class": "puck_control",
        "attributes": ["vertical"],
        "content_margin": [3,0],
    },    {
        "class": "puck_control",
        "attributes": ["horizontal"],
        "content_margin": [12,3],
    },
]
EOF
}



BuildAudacityStyles ()
{
    sys::Mkdir "$1"
    base64 -d <<'EOF' >"$1/ImageCache.png"
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
DgAEDgAEDgCBAwCBAwCBAwCBAwCBAwCBA0DgAEDgAEDgAEDgAEDgAEDgABA4ABA4ABA4ABA4ABA4
ABA4AAQOAAQOAAQOAAQOAAQuAoDAAYDAAYDAAYDAAYDAASBwACBwACBwACBwACBwACBwAAgcAAgc
AAgcAAgcAAgcAAgcAAIHAAIHAAIHAAIHAAIHgMABgMABgMABgMABgMABgMABIHAAIHAAIHAAIHAA
IHAAIHAACBwACBwACBwACBwACBwACBwAAgcAAgcAAgcAAgcAAgeAwAGAwAGAwAGAwAGAwAGAwAEg
cAAgcAAgcAAgcAAgcAAgcAAIHAAIHAAIHAAIHAAIHAAIHAACBwACBwACBwACBwACB4DAAYDAAYDA
AYDAAYDAAYDAASBwACBwACBwACBwACBwACBwAAgcAAgcAAgcAAgcAAgcAJNI4ABA4AAQOAAQOAAQ
OAAQOAAQOAAQOAAEDgAEDgAEDgAEDgAEDgAEDgCBAwCBAwCBAwCBAwCBA0DgAEDgAEDgAEDgAEDg
AEDgABA4ABA4ABA4ABA4ABA4ABA4AAQOAAQOAAQOAAQOAAQOAAQOAIEDAIEDAIEDAIEDAIEDQOAA
QOAAQOAAQOAAQOAAQOAAEDgAEDgAEDgAEDgAEDgAEDgABA4ABA4ABA4ABA4ABA4A/gvRrmnrfmi2
VAAAAABJRU5ErkJggg==
EOF

}

