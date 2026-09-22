-- Resolve the actual mount folder; Finder may not enumerate custom mounts as disks.
on run argv
    set mountFolder to (POSIX file (item 1 of argv)) as alias
    tell application "Finder"
        tell folder (mountFolder as text)
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set bounds of container window to {180, 140, 900, 644}
            set viewOptions to icon view options of container window
            set arrangement of viewOptions to not arranged
            set icon size of viewOptions to 96
            set text size of viewOptions to 13
            set background picture of viewOptions to file "ByteKibble.app:Contents:Resources:InstallerBackground.png"
            set position of item "ByteKibble.app" to {205, 172}
            set position of item "Applications" to {515, 172}
            close
            open
            update without registering applications
            delay 2
            close
            delay 2
        end tell
    end tell
end run
