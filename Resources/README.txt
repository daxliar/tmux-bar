App icon (pick one)

If both files below exist, AppIcon.icns wins.

1) Resources/AppIcon.icns (recommended for a final asset)
   Export or build a .icns file (e.g. from an asset catalog in Xcode, or with
   "iconutil" from an .iconset folder) and place it here. CMake bundles it
   as-is; no Python or sips step runs.

2) Resources/AppIcon.source.png (good while iterating)
   Use a square master image (1024x1024 PNG is ideal). CMake runs
   cmake/gen_app_icon.py at build time to resize with sips and produce AppIcon.icns.

If neither file is present, the build generates a temporary solid-color icon.

After adding or changing an icon file, reconfigure or rebuild so the bundle picks it up:
  cmake --build <your-build-dir>
