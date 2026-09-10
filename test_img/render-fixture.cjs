// Export the same Canvas drawing used by the Visualize fragment. No downloads.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { createCanvas } = require('@napi-rs/canvas');
const directory = __dirname;
const source = createCanvas(640,640);
const small = createCanvas(64,64);
const markup = fs.readFileSync(path.join(directory,'swamp-tile.html'),'utf8');
const script = markup.match(/<script>([\s\S]*?)<\/script>/)[1];
vm.runInNewContext(script, { document: {getElementById:()=>({querySelector:selector=>selector==='#swamp-source'?source:small})}, Math });
fs.mkdirSync(path.join(directory,'input'),{recursive:true});
fs.mkdirSync(path.join(directory,'output'),{recursive:true});
fs.writeFileSync(path.join(directory,'input','swamp-hex-30deg-640.png'),source.toBuffer('image/png'));
// The requested 64px file is made with Aseprite. Keep the Canvas reference in
// target/ for a pixel-for-pixel check of the comparison shown in Visualize.
fs.mkdirSync(path.join(directory,'..','target'),{recursive:true});
fs.writeFileSync(path.join(directory,'..','target','swamp-canvas-reference-64.png'),small.toBuffer('image/png'));
console.log('SWAMP_FIXTURE_READY: 640x640 RGBA, 30-degree elevation');
