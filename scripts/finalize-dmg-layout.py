"""Create native Finder metadata; requires ds-store 1.3.1, mac-alias 2.2.2."""
from pathlib import Path
import sys
from ds_store import DSStore
from mac_alias import Alias, Bookmark

mount = Path(sys.argv[1]).resolve()
background = mount / "ByteKibble.app/Contents/Resources/InstallerBackground.png"
window = dict(WindowBounds="{{180, 140}, {720, 540}}", ShowStatusBar=False,
              ShowToolbar=False, ShowPathbar=False, ShowSidebar=False,
              ShowTabView=False, ContainerShowSidebar=False,
              PreviewPaneVisibility=False, SidebarWidth=0)
icons = dict(viewOptionsVersion=1, backgroundType=2,
             backgroundColorRed=1.0, backgroundColorGreen=1.0,
             backgroundColorBlue=1.0,
             backgroundImageAlias=Alias.for_file(str(background)).to_bytes(),
             gridOffsetX=0.0, gridOffsetY=0.0, gridSpacing=100.0,
             arrangeBy="none", showIconPreview=True, showItemInfo=False,
             labelOnBottom=True, textSize=13.0, iconSize=96.0,
             scrollPositionX=0.0, scrollPositionY=0.0)
with DSStore.open(str(mount / ".DS_Store"), "w+") as store:
    store["."]["vSrn"] = ("long", 1)
    store["."]["bwsp"] = window
    store["."]["icvp"] = icons
    store["."]["pBBk"] = Bookmark.for_file(str(background))
    store["."]["icvl"] = ("type", b"icnv")
    store["ByteKibble.app"]["Iloc"] = (205, 180)
    store["Applications"]["Iloc"] = (515, 180)
print("Saved 720x540 Finder window and two centered installation icons")
