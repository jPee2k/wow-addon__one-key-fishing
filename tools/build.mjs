// Packages the addon into dist/OneKeyFishing/ and dist/OneKeyFishing-<version>.zip.
//   --dev      files from the working folder, version "<package version>-dev+<commit>"
//   --release  files from the last commit, version from package.json; refuses uncommitted changes, then
//              runs tools/check.mjs and the tests before packaging
// Only the TOC, the files it lists, Bindings.xml and LICENSE / README.md / CHANGELOG.md are packaged
// (tools/addon.mjs), so nothing else can slip in.
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { zipSync } from "fflate";
import { ADDON, ROOT, DIST, TOC, packageEntries, fail } from "./addon.mjs";

const mode = process.argv[2];
if (mode !== "--dev" && mode !== "--release") {
  fail("usage: node tools/build.mjs --dev | --release");
}
const release = mode === "--release";

function git(...args) {
  return execFileSync("git", args, { cwd: ROOT, maxBuffer: 64 * 1024 * 1024 });
}

function gitText(...args) {
  return git(...args).toString("utf8").trim();
}

// Runs another script of the project; its output goes straight to the terminal, a failure stops the build.
function runScript(script) {
  try {
    execFileSync(process.execPath, [path.join(ROOT, script)], { cwd: ROOT, stdio: "inherit" });
  } catch {
    fail(`${script} failed`);
  }
}

let readFile;
let version;
if (release) {
  if (gitText("status", "--porcelain") !== "") {
    fail("there are uncommitted changes; commit them first (or use `npm run dev`)");
  }
  runScript("tools/check.mjs");
  runScript("tests/run.mjs");
  readFile = (file) => git("show", `HEAD:${file}`);
  version = JSON.parse(readFile("package.json").toString("utf8")).version;
} else {
  readFile = (file) => fs.readFileSync(path.join(ROOT, file));
  let commit = "nogit";
  try {
    commit = gitText("rev-parse", "--short", "HEAD");
  } catch {
    // Not a git checkout: the dev version just has no commit.
  }
  version = `${JSON.parse(readFile("package.json").toString("utf8")).version}-dev+${commit}`;
}

const files = packageEntries(readFile(`${ADDON}/${TOC}`).toString("utf8"));
const contents = {};
for (const { from, to } of files) {
  let data;
  try {
    data = readFile(from);
  } catch {
    fail(`"${from}" is listed for packaging but cannot be read`);
  }
  // Like the release packager: in every text file, not only the TOC (check.mjs keeps it out of the others).
  if (/\.(toc|lua|xml)$/.test(to)) {
    data = Buffer.from(data.toString("utf8").replaceAll("@project-version@", version), "utf8");
  }
  contents[to] = data;
}

fs.rmSync(DIST, { recursive: true, force: true });
const folder = path.join(DIST, ADDON);
const zipEntries = {};
for (const [file, data] of Object.entries(contents)) {
  const target = path.join(folder, ...file.split("/"));
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, data);
  zipEntries[`${ADDON}/${file}`] = new Uint8Array(data);
}

const zipName = `${ADDON}-${version.replace(/[^0-9A-Za-z.-]/g, "-")}.zip`;
fs.writeFileSync(path.join(DIST, zipName), zipSync(zipEntries, { level: 9 }));

console.log(`Built ${ADDON} ${version} (${release ? "release, from HEAD" : "dev, from the working folder"}):`);
console.log(`  dist/${ADDON}/  (${files.length} files)`);
console.log(`  dist/${zipName}`);
