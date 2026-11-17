// Renders the volume steps of the addon's sounds (spec 013, research R5): for every master
// OneKeyFishing/Media/Sounds/<name>.ogg, a copy at each step of VOLUME_STEPS in Media/Sounds/Volume<step>/<name>.ogg.
// PlaySoundFile has no volume argument, so the addon picks the file of the chosen volume.
//   npm run sounds
// Needs ffmpeg: on PATH, or its path in the FFMPEG environment variable. Run it after a master is added or
// changed; the rendered files are committed (npm run check reports a master without its steps).
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { ADDON_DIR, SOUNDS_DIR, VOLUME_STEPS, fail } from "./addon.mjs";

const ffmpeg = process.env.FFMPEG || "ffmpeg";
try {
  execFileSync(ffmpeg, ["-version"], { stdio: "ignore" });
} catch {
  fail("ffmpeg is needed for npm run sounds (install it, or set FFMPEG to its path)");
}

const soundsDir = path.join(ADDON_DIR, ...SOUNDS_DIR.split("/"));
const masters = fs.existsSync(soundsDir)
  ? fs.readdirSync(soundsDir).filter((name) => name.toLowerCase().endsWith(".ogg")).sort()
  : [];
if (masters.length === 0) {
  fail(`no .ogg master in ${SOUNDS_DIR}`);
}

let count = 0;
for (const step of VOLUME_STEPS) {
  const dir = path.join(soundsDir, `Volume${step}`);
  fs.mkdirSync(dir, { recursive: true });
  // A step whose master was renamed or removed would fail npm run check: it goes.
  for (const name of fs.readdirSync(dir)) {
    if (!masters.includes(name)) {
      fs.rmSync(path.join(dir, name));
    }
  }
  for (const name of masters) {
    // Amplitude step/100, re-encoded as Ogg Vorbis (quality 4, about 128 kbit/s); metadata is dropped.
    execFileSync(ffmpeg, ["-y", "-loglevel", "error", "-i", path.join(soundsDir, name), "-map_metadata", "-1",
      "-filter:a", `volume=${step / 100}`, "-c:a", "libvorbis", "-q:a", "4", path.join(dir, name)],
    { stdio: "inherit" });
    count += 1;
  }
}
console.log(`Rendered ${count} files: ${masters.length} sounds x ${VOLUME_STEPS.length} volume steps.`);
