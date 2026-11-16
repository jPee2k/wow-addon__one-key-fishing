// tools/addon.mjs mediaProblems and packageEntries: the sound files under OneKeyFishing/Media/ (constitution 1.5.4,
// spec 013 research R5): only .ogg there, every master with its nine volume steps, every step with its master, and
// the .ogg files packaged without a TOC line. Run by tests/run.mjs (exports `tests`).
import assert from "node:assert/strict";
import { mediaProblems, packageEntries, VOLUME_STEPS } from "../../tools/addon.mjs";

const master = "Media/Sounds/bell.ogg";
const steps = VOLUME_STEPS.map((step) => `Media/Sounds/Volume${step}/bell.ogg`);

export const tests = [
  {
    name: "a master with all its steps is fine",
    fn: () => {
      assert.deepEqual(mediaProblems([master, ...steps]), []);
    },
  },
  {
    name: "a master without a step is a problem that names the step",
    fn: () => {
      const problems = mediaProblems([master, ...steps.filter((file) => !file.includes("Volume30"))]);
      assert.equal(problems.length, 1);
      assert.equal(problems[0].file, master);
      assert.match(problems[0].message, /30/);
    },
  },
  {
    name: "a step without its master and a step that is not a step are problems",
    fn: () => {
      const files = mediaProblems(["Media/Sounds/Volume20/hook.ogg", "Media/Sounds/Volume15/bell.ogg", master,
        ...steps]);
      assert.deepEqual(files.map((p) => p.file).sort(),
        ["Media/Sounds/Volume15/bell.ogg", "Media/Sounds/Volume20/hook.ogg"]);
    },
  },
  {
    name: "any file type but .ogg under Media/ is a problem",
    fn: () => {
      const problems = mediaProblems(["Media/notes.txt", "Media/Sounds/x.wav"]);
      assert.deepEqual(problems.map((p) => p.file), ["Media/notes.txt", "Media/Sounds/x.wav"]);
    },
  },
  {
    name: "a master in another letter case or a file in another folder of Media/Sounds is a problem",
    fn: () => {
      const problems = mediaProblems(["Media/Sounds/Bell.OGG", "Media/Sounds/Extra/x.ogg", master, ...steps]);
      assert.deepEqual(problems.map((p) => p.file).sort(), ["Media/Sounds/Bell.OGG", "Media/Sounds/Extra/x.ogg"]);
    },
  },
  {
    name: "the .ogg files are packaged next to the TOC files, nothing else from Media/",
    fn: () => {
      const toc = "## Interface: 16001\nCore\\Core.lua\n";
      const entries = packageEntries(toc, [master, ...steps, "Media/notes.txt"]);
      const targets = entries.map((entry) => entry.to);
      assert.ok(targets.includes(master), "the master");
      assert.ok(targets.includes(steps[0]), "a step");
      assert.ok(!targets.includes("Media/notes.txt"), "no other file");
      assert.ok(targets.includes("Core/Core.lua"), "the TOC files");
      assert.deepEqual(entries.find((entry) => entry.to === master),
        { from: `OneKeyFishing/${master}`, to: master });
    },
  },
];
