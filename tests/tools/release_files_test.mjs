// tools/addon.mjs packageEntries (specs/027-import-export, FR-016): a package holds only the TOC, the files it
// lists, Bindings.xml, the player manual and the Media sounds, plus LICENSE and CHANGELOG.md; a Lua file in the
// addon folder that the TOC does not list never ships.
import assert from "node:assert/strict";
import { packageEntries } from "../../tools/addon.mjs";

const TOC_TEXT = ["## Interface: 16001", "## Title: OneKeyFishing", "Core\\Core.lua", "UI\\Settings.lua", ""]
  .join("\n");

export const tests = [
  {
    name: "the package is the TOC, its files, the extras and the sounds",
    fn() {
      const media = ["Media/Sounds/Bell.ogg", "Media/notes.txt"];
      const files = packageEntries(TOC_TEXT, media).map((entry) => entry.to).sort();
      assert.deepEqual(files, ["Bindings.xml", "CHANGELOG.md", "Core/Core.lua", "LICENSE", "Media/Sounds/Bell.ogg",
        "OneKeyFishing.toc", "README.md", "UI/Settings.lua"].sort());
    },
  },
  {
    name: "a Lua file the TOC does not list is not packaged",
    fn() {
      const lua = packageEntries(TOC_TEXT, []).map((entry) => entry.to).filter((file) => file.endsWith(".lua"));
      assert.deepEqual(lua.sort(), ["Core/Core.lua", "UI/Settings.lua"], "only the TOC's Lua files");
    },
  },
];
