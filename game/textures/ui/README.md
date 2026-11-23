# Menu art

Icons, the three characters' faces, the mohalla street, the title picture and the painted band, drawn for
this game as SVG (the sources) and drawn out as PNG by `node tool/render_ui.js` (Playwright). The game
reads the PNGs as they are (importer "keep"): the Android export templates have no SVG reader. Line icons
are white so a tint colours them. After changing an SVG, run the script and commit both files.
