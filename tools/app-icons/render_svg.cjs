// Pinned build-time renderer; never included in the app.
const { Resvg } = require('@resvg/resvg-js');
const fs = require('node:fs');
process.stdout.write(new Resvg(fs.readFileSync(0), { font: { loadSystemFonts: false } }).render().asPng());
