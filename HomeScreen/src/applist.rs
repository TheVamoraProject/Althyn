#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }
    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        type AppList = super::AppListRust;
        #[qinvokable]
        #[cxx_name = "getAppsJson"]
        fn get_apps_json(self: &AppList) -> QString;
        #[qinvokable]
        #[cxx_name = "getGrid"]
        fn get_grid(self: &AppList) -> QString;
        #[qinvokable]
        #[cxx_name = "loadLayout"]
        fn load_layout(self: &AppList) -> QString;
        #[qinvokable]
        #[cxx_name = "saveLayout"]
        fn save_layout(self: &AppList, json: &QString);
        #[qinvokable]
        #[cxx_name = "launchApp"]
        fn launch_app(self: &AppList, exec: &QString);
        #[qinvokable]
        #[cxx_name = "removeApp"]
        fn remove_app(self: &AppList, desktop_path: &QString);
        #[qinvokable]
        #[cxx_name = "shutdown"]
        fn shutdown(self: &AppList);
        /// Reads `icons.corner_radius` (0-32, 32 = full circle) from
        /// VamoraSys once at startup, same as the launcher and start menu.
        #[qinvokable]
        #[cxx_name = "getIconCornerRadius"]
        fn get_icon_corner_radius(self: &AppList) -> QString;
        /// Scans ~/Desktop for `.widget` manifests (the widget equivalent
        /// of `.desktop` files) and resolves each one's actual QML file
        /// under ~/.VamoraSys/althyn/homescreen/widgets/<Package>/<Source>.
        #[qinvokable]
        #[cxx_name = "getWidgetsJson"]
        fn get_widgets_json(self: &AppList) -> QString;
    }
}

use cxx_qt_lib::QString;
use std::{path::{Path, PathBuf}, process::Command};

#[derive(Default)]
pub struct AppListRust;

impl qobject::AppList {
    pub fn get_apps_json(&self) -> QString { QString::from(apps_to_json(&scan_desktop_dir()).as_str()) }
    pub fn get_grid(&self) -> QString {
        let output = Command::new("vamorasys").args(["settings", "get", "homescreen.grid"]).output();
        let raw = output.ok().map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string()).unwrap_or_default();
        let grid = if parse_grid(&raw).is_some() { raw } else { "4x6".to_string() };
        QString::from(grid.as_str())
    }
    pub fn load_layout(&self) -> QString { QString::from(read_layout().as_deref().unwrap_or("") ) }
    pub fn save_layout(&self, json: &QString) { let _ = write_layout(&format!("{}", json)); }
    pub fn launch_app(&self, exec: &QString) {
        let cleaned = clean_exec(&format!("{}", exec)); let mut parts = cleaned.split_whitespace();
        if let Some(bin) = parts.next() { let _ = Command::new(bin).args(parts).spawn(); }
    }
    pub fn remove_app(&self, desktop_path: &QString) { let path = format!("{}", desktop_path); if !path.is_empty() { let _ = std::fs::remove_file(path); } }
    pub fn shutdown(&self) { if Command::new("systemctl").arg("poweroff").spawn().is_err() { let _ = Command::new("shutdown").args(["-h", "now"]).spawn(); } }
    pub fn get_icon_corner_radius(&self) -> QString {
        let radius = Command::new("vamorasys").args(["settings", "get", "icons.corner_radius"]).output().ok()
            .and_then(|o| String::from_utf8(o.stdout).ok())
            .map(|v| v.trim().to_string())
            .and_then(|v| v.parse::<f64>().ok())
            .filter(|v| v.is_finite() && *v >= 0.0)
            .unwrap_or(8.0);
        QString::from(radius.to_string().as_str())
    }
    pub fn get_widgets_json(&self) -> QString { QString::from(widgets_to_json(&scan_widget_files()).as_str()) }
}

struct App { name: String, icon_path: String, exec: String, desktop_path: String, id: String, direct_round: bool, bg_color: String }
// A widget: a `.widget` manifest sitting in ~/Desktop next to the app
// .desktop files, e.g.:
//   [Widget]
//   Name=Clock
//   Id=clock
//   Package=com.vamora.clock
//   Version=1.0
//
//   [UI]
//   Type=QML
//   Source=clock.qml
//
//   [Size]
//   Width=2
//   Height=1
//   MinWidth=1
//   MinHeight=1
//   MaxWidth=4
//   MaxHeight=2
// `source` resolves to the actual QML file at
// ~/.VamoraSys/althyn/homescreen/widgets/<Package>/<Source> — that's what
// gets loaded and rounded, not an icon. `vamify` (optional, default true)
// controls whether that rendered content gets rounded corners at all.
struct Widget {
    id: String,
    name: String,
    package: String,
    source: String,
    width: i32,
    height: i32,
    min_width: i32,
    min_height: i32,
    max_width: i32,
    max_height: i32,
    vamify: bool,
}

fn homescreen_dir() -> Option<PathBuf> { std::env::var("HOME").ok().map(|h| PathBuf::from(h).join(".VamoraSys/althyn/homescreen")) }
fn layout_path() -> Option<PathBuf> { homescreen_dir().map(|p| p.join("layout.json")) }
fn read_layout() -> Option<String> { std::fs::read_to_string(layout_path()?).ok() }
fn write_layout(json: &str) -> std::io::Result<()> {
    let dir = homescreen_dir().ok_or(std::io::Error::new(std::io::ErrorKind::NotFound, "HOME unset"))?;
    std::fs::create_dir_all(&dir)?;
    let tmp = dir.join("layout.json.tmp"); std::fs::write(&tmp, json)?; std::fs::rename(tmp, dir.join("layout.json"))
}
fn parse_grid(s: &str) -> Option<(i32,i32)> { let mut p=s.trim().split('x'); Some((p.next()?.parse().ok()?, p.next()?.parse().ok()?)) }
fn scan_desktop_dir() -> Vec<App> {
    let Some(home) = std::env::var_os("HOME").map(PathBuf::from) else { return vec![] };
    let dir = home.join("Desktop");
    let Ok(entries) = std::fs::read_dir(dir) else { return vec![] };
    let mut apps = vec![];
    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().and_then(|x| x.to_str()) == Some("desktop") {
            if let Some(app) = parse_desktop_file(&path) { apps.push(app); }
        }
    }
    apps.sort_by_key(|a| a.name.to_lowercase());
    apps
}
fn parse_desktop_file(path: &Path) -> Option<App> {
    let content=std::fs::read_to_string(path).ok()?; let mut active=false; let mut name=String::new(); let mut icon=String::new(); let mut exec=String::new(); let mut typ=String::new(); let mut hidden=false; let mut direct_round=false; let mut bg_color=String::new();
    for line in content.lines().map(str::trim) { if line=="[Desktop Entry]" {active=true;continue} if line.starts_with('[')&&active{break} if !active{continue}
        if let Some(v)=line.strip_prefix("Name="){if name.is_empty(){name=v.into()}} else if let Some(v)=line.strip_prefix("Icon="){if icon.is_empty(){icon=v.into()}} else if let Some(v)=line.strip_prefix("Exec="){if exec.is_empty(){exec=v.into()}} else if let Some(v)=line.strip_prefix("Type="){typ=v.into()} else if line=="NoDisplay=true"||line=="Hidden=true"{hidden=true} else if let Some(v)=line.strip_prefix("VamoraPackage="){if !v.trim().is_empty(){direct_round=true}} else if let Some(v)=line.strip_prefix("BGColor="){if v.trim().starts_with('#'){bg_color=v.trim().to_string()}}
    }
    if typ!="Application"||hidden||name.is_empty()||exec.is_empty(){return None} let id=path.file_name()?.to_string_lossy().to_string(); Some(App{name,icon_path:resolve_icon(&icon),exec:clean_exec(&exec),desktop_path:path.to_string_lossy().into(),id,direct_round,bg_color})
}
fn clean_exec(exec:&str)->String { let mut out=String::new(); let mut c=exec.chars().peekable(); while let Some(x)=c.next(){if x=='%' { c.next(); } else { out.push(x); }}; out.split_whitespace().collect::<Vec<_>>().join(" ") }
fn resolve_icon(icon:&str)->String { if icon.starts_with('/')&&Path::new(icon).exists(){return format!("file://{icon}")} for p in [format!("/usr/share/icons/hicolor/48x48/apps/{icon}.png"),format!("/usr/share/icons/hicolor/scalable/apps/{icon}.svg"),format!("/usr/share/pixmaps/{icon}.png"),format!("/usr/share/pixmaps/{icon}.svg")] {if Path::new(&p).exists(){return format!("file://{p}")}} String::new() }
fn esc(s:&str)->String{s.replace('\\',"\\\\").replace('"',"\\\"").replace('\n',"\\n").replace('\r',"\\r")}
fn apps_to_json(apps:&[App])->String { let mut o=String::from("["); for (i,a) in apps.iter().enumerate(){if i>0{o.push(',')} o.push_str(&format!(r#"{{"appName":"{}","iconPath":"{}","execStr":"{}","desktopPath":"{}","id":"{}","directRound":{},"bgColor":"{}"}}"#,esc(&a.name),esc(&a.icon_path),esc(&a.exec),esc(&a.desktop_path),esc(&a.id),a.direct_round,esc(&a.bg_color)))} o.push(']');o }

fn scan_widget_files() -> Vec<Widget> {
    let Some(home) = std::env::var_os("HOME").map(PathBuf::from) else { return vec![] };
    let dir = home.join("Desktop");
    let Ok(entries) = std::fs::read_dir(&dir) else { return vec![] };
    let mut widgets = vec![];
    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().and_then(|x| x.to_str()) == Some("widget") {
            if let Some(widget) = parse_widget_file(&path, &home) { widgets.push(widget); }
        }
    }
    widgets.sort_by_key(|w| w.name.to_lowercase());
    widgets
}
fn parse_widget_file(path: &Path, home: &Path) -> Option<Widget> {
    let content = std::fs::read_to_string(path).ok()?;
    let mut section = String::new();
    let mut name = String::new();
    let mut id = String::new();
    let mut package = String::new();
    let mut ui_type = String::new();
    let mut source_file = String::new();
    let (mut width, mut height) = (1i32, 1i32);
    let (mut min_width, mut min_height) = (1i32, 1i32);
    let (mut max_width, mut max_height) = (0i32, 0i32); // resolved after Width/Height are known
    // Missing entirely means "rounded by default" — same convention as an
    // app being direct-round-safe once it has no icon to worry about.
    let mut vamify = true;

    for raw_line in content.lines() {
        let line = raw_line.trim();
        if line.starts_with('[') && line.ends_with(']') {
            section = line[1..line.len() - 1].to_string();
            continue;
        }
        let Some((key, value)) = line.split_once('=') else { continue };
        let value = value.trim();
        match section.as_str() {
            "Widget" => match key {
                "Name" => name = value.to_string(),
                "Id" => id = value.to_string(),
                "Package" => package = value.to_string(),
                "Vamify" => vamify = !value.eq_ignore_ascii_case("false"),
                _ => {}
            },
            "UI" => match key {
                "Type" => ui_type = value.to_string(),
                "Source" => source_file = value.to_string(),
                _ => {}
            },
            "Size" => match key {
                "Width" => width = value.parse().unwrap_or(1),
                "Height" => height = value.parse().unwrap_or(1),
                "MinWidth" => min_width = value.parse().unwrap_or(1),
                "MinHeight" => min_height = value.parse().unwrap_or(1),
                "MaxWidth" => max_width = value.parse().unwrap_or(0),
                "MaxHeight" => max_height = value.parse().unwrap_or(0),
                _ => {}
            },
            _ => {}
        }
    }

    if name.is_empty() || id.is_empty() || package.is_empty() || source_file.is_empty() {
        return None;
    }
    // Only QML widgets are supported right now.
    if !ui_type.eq_ignore_ascii_case("QML") {
        return None;
    }
    let qml_path = home
        .join(".VamoraSys/althyn/homescreen/widgets")
        .join(&package)
        .join(&source_file);
    if !qml_path.exists() {
        return None;
    }
    if max_width < width { max_width = width; }
    if max_height < height { max_height = height; }

    Some(Widget {
        id,
        name,
        package,
        source: format!("file://{}", qml_path.to_string_lossy()),
        width,
        height,
        min_width,
        min_height,
        max_width,
        max_height,
        vamify,
    })
}
fn widgets_to_json(widgets: &[Widget]) -> String {
    let mut o = String::from("[");
    for (i, w) in widgets.iter().enumerate() {
        if i > 0 { o.push(',') }
        o.push_str(&format!(
            r#"{{"id":"{}","name":"{}","package":"{}","source":"{}","width":{},"height":{},"minWidth":{},"minHeight":{},"maxWidth":{},"maxHeight":{},"vamify":{}}}"#,
            esc(&w.id), esc(&w.name), esc(&w.package), esc(&w.source),
            w.width, w.height, w.min_width, w.min_height, w.max_width, w.max_height, w.vamify
        ));
    }
    o.push(']');
    o
}

#[cfg(test)]
mod tests { use super::*; #[test] fn grid_parses(){assert_eq!(parse_grid("5x7"),Some((5,7)));} #[test] fn exec_codes_removed(){assert_eq!(clean_exec("foo %U --bar"),"foo --bar");} }
