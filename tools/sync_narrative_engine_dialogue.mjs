import { readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const toolDirectory = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(toolDirectory, "..");
const dialoguePath = join(projectRoot, "data", "narrative", "daily_dialogue.json");
const htmlPath = join(
  projectRoot,
  "output",
  "narrative-engine",
  "formocracy-narrative-engine.html",
);
const openMarker = '<script id="dailyDialogueSeed" type="application/json">';
const closeMarker = "</script>";

const dialogue = JSON.parse(await readFile(dialoguePath, "utf8"));
const source = await readFile(htmlPath, "utf8");
const start = source.indexOf(openMarker);
const end = source.indexOf(closeMarker, start + openMarker.length);
if (start < 0 || end < 0) {
  throw new Error("Unable to locate the daily dialogue seed in the narrative engine");
}
const next =
  source.slice(0, start + openMarker.length) +
  `${JSON.stringify(dialogue, null, 2)}\n  ` +
  source.slice(end);
await writeFile(htmlPath, next, "utf8");
process.stdout.write(
  `FORMOCRACY_NARRATIVE_DIALOGUE_SYNC_OK days=${dialogue.days.length}\n`,
);
