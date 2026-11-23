import json, os, shutil, sys, subprocess
V = sys.argv[1]
H = "/tmp/sc/home"
EX = "/home/claude/mig/althyn-desktop-environment/examples/widgets"
shutil.rmtree("/tmp/sc", ignore_errors=True)
for d in ["Desktop", ".VamoraSys/althyn/runner", ".VamoraSys/althyn/dock/contents", ".VamoraSys/althyn/homescreen/widgets", "Documents", "Pictures"]:
    os.makedirs(f"{H}/{d}", exist_ok=True)
open(f"{H}/.VamoraSys/althyn/runner/first-run-done", "w").close()
APPS = {  # name: (icon, exec)
 "Files":("system-file-manager",), "Firefox":("firefox",), "Terminal":("utilities-terminal",), "Settings":("preferences-system",),
 "Music":("spotify",), "Mail":("thunderbird",), "Code":("visual-studio-code",), "Photos":("image-viewer",),
 "Calculator":("accessories-calculator",), "Maps":("org.gnome.Maps",), "Telegram":("telegram",), "GIMP":("gimp",),
 "Blender":("blender",), "Steam":("steam",), "Discord":("discord",), "Notes":("accessories-text-editor",),
 "Chromium":("chromium",), "VLC":("vlc",), "Inkscape":("inkscape",), "Kdenlive":("kdenlive",), "Writer":("libreoffice-writer",),
 "Calc":("libreoffice-calc",), "Impress":("libreoffice-impress",), "Krita":("krita",), "Slack":("slack",), "Brave":("brave-browser",),
 "Signal":("signal-desktop",), "Transmission":("transmission",), "Cheese":("org.gnome.Cheese",), "Obsidian":("obsidian",),
 "Calendar":("org.gnome.Calendar",), "Contacts":("org.gnome.Contacts",), "Evince":("evince",), "Books":("org.gnome.Books",),
 "Audacity":("audacity",), "VirtualBox":("virtualbox",), "qBittorrent":("qbittorrent",), "GitHub":("github-desktop",),
 "Postman":("postman",), "Android Studio":("android-studio",), "Godot":("godot",), "Bitwarden":("bitwarden",), "Dropbox":("dropbox",),
}
ORDER = {
 "aurora":   ["Files","Firefox","Mail","Calendar","Photos","Maps","Music","Telegram","Discord","Code","GitHub","GIMP","Blender","Krita","Steam","Writer","Notes","Calculator"],
 "monument": ["Firefox","Files","Mail","Maps","Code","Terminal","Music","Photos","Telegram","Signal","GIMP","Inkscape","Steam","Obsidian","Writer","Calendar"],
 "provence": ["Files","Firefox","Mail","Calendar","Photos","Maps","Music","Code","Terminal","GIMP","Krita","Blender","Telegram","Discord","Steam","Writer","Notes","Calculator"],
 "fuji":     ["Files","Firefox","Mail","Calendar","Photos","Maps","Music","Telegram","Code","GitHub","Terminal","GIMP","Krita","Blender","Steam","Writer","Obsidian","Notes"],
}
import colorsys
HUE = {"Files":210,"Firefox":25,"Mail":215,"Calendar":0,"Photos":195,"Maps":140,"Music":140,"Telegram":200,"Discord":235,"Signal":220,
       "Slack":300,"Code":210,"GitHub":270,"Terminal":160,"Settings":175,"GIMP":30,"Krita":280,"Blender":28,"Steam":205,"VLC":30,
       "Obsidian":265,"Notes":45,"Calculator":150,"Chromium":215,"Brave":15,"Writer":215,"Calc":130,"Godot":210,"Inkscape":200,"Kdenlive":220}
def tint(name, mode):
    if mode is None: return None
    h = HUE.get(name, 200) / 360
    r, g, b = colorsys.hls_to_rgb(h, 0.17 if mode == "dark" else 0.93, 0.35 if mode == "dark" else 0.75)
    return "#%02x%02x%02x" % (int(r*255), int(g*255), int(b*255))
TILES = None
def desk(path, name):
    icon = APPS[name][0]
    open(f"{path}/{name}.desktop", "w").write(f"[Desktop Entry]\nType=Application\nName={name}\nExec=true\nIcon={icon}\nCategories=Utility;\n" + (f"BGColor={tint(name, TILES)}\n" if TILES else ""))
CFG = {
 "aurora":   dict(radius=14, accent="#7dd3fc", theme="Papirus-Dark", grid="10x5", wall="aurora", tiles="dark",
                  dock=["Files","Firefox","Terminal","Code","Music","Settings"],
                  widgets=[("Clock",0,0,2,2),("Weather",4,0,3,1),("Calendar",8,0,2,2)]),
 "monument": dict(radius=32, accent="#fb923c", theme="Papirus", grid="10x5", wall="monument",
                  dock=["Firefox","Files","Music","Photos","Notes","Settings"],
                  widgets=[("Notes",8,0,2,2),("Clock",0,3,2,2)]),
 "provence": dict(radius=32, accent="#a3e635", theme="Tela-circle", grid="10x5", wall="provence",
                  dock=["Files","Firefox","Mail","Terminal","Calculator","Settings"],
                  widgets=[("Calendar",0,0,2,2),("Weather",7,0,3,1)]),

 "fuji":     dict(radius=18, accent="#f472b6", theme="Papirus", grid="10x5", wall="fuji", tiles="pastel",
                  dock=["Files","Firefox","Mail","Music","Terminal","Settings"],
                  widgets=[("Clock",0,0,2,2),("Notes",8,0,2,2),("Weather",3,0,3,1)]),
}[V]
TILES = CFG.get("tiles")
for n in CFG["dock"]: desk(f"{H}/.VamoraSys/althyn/dock/contents", n)
items = []
c, r = [int(x) for x in CFG["grid"].split("x")]
taken = set()
for n, x, y, w, h in CFG["widgets"]:
    for i in range(w):
        for j in range(h): taken.add((x+i, y+j))
    shutil.copytree(f"{EX}/{n}", f"{H}/.VamoraSys/althyn/homescreen/widgets/{n}")
    shutil.copy(f"{EX}/{n}/{n}.widget", f"{H}/Desktop/{n}.widget")
    items.append({"type":"widget","package":n,"name":n,"x":x,"y":y,"width":w,"height":h,"page":0})
free = [(x, y) for y in range(r) for x in range(c) if (x, y) not in taken]
for n, (x, y) in zip([a for a in ORDER[V] if a not in CFG["dock"] or a in ("Files","Firefox","Music","Photos","Terminal","Code")], free):
    desk(f"{H}/Desktop", n); items.append({"type":"app","id":f"{n}.desktop","x":x,"y":y,"width":1,"height":1,"page":0})
json.dump({"version":1,"grid":{"columns":c,"rows":r},"pages":[{"id":0,"items":items}],"folders":{}}, open(f"{H}/.VamoraSys/althyn/homescreen/layout.json","w"))
open(f"{H}/.vamorasys-stub","w").write(f"icons.corner_radius={CFG['radius']}\nappearance.accent_color={CFG['accent']}\nicons.theme={CFG['theme']}\nhomescreen.grid={CFG['grid']}\n")
open("/tmp/sc/wall","w").write(f"/home/claude/showcase/wall/{CFG['wall']}.jpg")
