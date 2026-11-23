# Menu art

Icons, the three characters' faces, the mohalla street, the title picture and the painted band, drawn for
this game as SVG. `node tool/render_ui.js` (Playwright) draws them out as PNG into game/textures/ui/,
which Godot imports as textures for the menus. Line icons are white so a
tint colours them. After changing an SVG, run the script and commit both.
