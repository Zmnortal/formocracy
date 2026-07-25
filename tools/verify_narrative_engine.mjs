import { readFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const toolDirectory = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(toolDirectory, "..");
const htmlPath = join(
  projectRoot,
  "output",
  "narrative-engine",
  "formocracy-narrative-engine.html",
);
const dialoguePath = join(projectRoot, "data", "narrative", "daily_dialogue.json");
const html = await readFile(htmlPath, "utf8");
const dialogue = JSON.parse(await readFile(dialoguePath, "utf8"));

const seedMatch = html.match(
  /<script id="dailyDialogueSeed" type="application\/json">([\s\S]*?)<\/script>/,
);
if (!seedMatch) throw new Error("daily dialogue seed is missing");
const embedded = JSON.parse(seedMatch[1]);
if (JSON.stringify(embedded) !== JSON.stringify(dialogue)) {
  throw new Error("embedded daily dialogue seed differs from project JSON");
}

const scriptMatches = [...html.matchAll(/<script(?![^>]*type="application\/json")[^>]*>([\s\S]*?)<\/script>/g)];
if (scriptMatches.length !== 1) {
  throw new Error(`expected one executable script, received ${scriptMatches.length}`);
}
new vm.Script(scriptMatches[0][1], { filename: htmlPath });

const lines = dialogue.days.flatMap((day) => [...day.daytime, ...day.evening]);
for (const required of [
  "第 06 工作日 23:40，杜春梅被登记死亡",
  "七日试行期已经结束。感谢前来试玩",
  "只有批准且在第六夜前完成验收",
]) {
  if (!html.includes(required)) throw new Error(`missing narrative text: ${required}`);
}
if (dialogue.days.length !== 7) throw new Error("dialogue must cover seven days");
if (!dialogue.days.every((day) => day.daytime.length && day.evening.length)) {
  throw new Error("every day must include daytime and evening dialogue");
}

process.stdout.write(
  `FORMOCRACY_NARRATIVE_ENGINE_OK days=${dialogue.days.length} lines=${lines.length} scripts=${scriptMatches.length}\n`,
);
