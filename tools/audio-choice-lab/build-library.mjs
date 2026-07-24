import { createHash } from "node:crypto";
import { copyFile, mkdir, readdir, readFile, writeFile } from "node:fs/promises";
import { extname, join } from "node:path";

const sourceRoot = "/Users/amin/Desktop/FORMOCRACY/audios";
const outputRoot = new URL("./audio/library/", import.meta.url);
const manifestPath = new URL("./voice-library.json", import.meta.url);
const audioExtensions = new Set([".wav", ".mp3", ".flac", ".ogg", ".aiff", ".aif", ".m4a"]);

const groups = [
  {
    path: "FS Free Human Voices/SOUNDS", prefix: "FS", source: "FS Free Human Voices", license: "免费商用",
    classify(name) {
      return `${name.startsWith("Male") ? "male" : "female"}-${name.includes("Type 2") ? "old" : "young"}`;
    },
  },
  {
    path: "young Female Voice Clips/Audio", prefix: "GF", source: "Free Generic Female Voice Pack",
    license: "免费商用 / 需署名", classify: () => "female-young",
  },
  {
    path: "Male protagonist", prefix: "MP", source: "Male protagonist",
    license: "素材包授权待复核", classify: () => "male-young",
  },
  {
    path: "RPG Voice Starter Pack/Type 1", prefix: "R1", source: "RPG Voice Starter Pack / Type 1",
    license: "CC0", classify: () => "female-young",
  },
  {
    path: "RPG Voice Starter Pack/Type 2", prefix: "R2", source: "RPG Voice Starter Pack / Type 2",
    license: "CC0", classify: () => "female-young",
  },
  {
    path: "RPG Voice Starter Pack/Type 3", prefix: "R3", source: "RPG Voice Starter Pack / Type 3",
    license: "CC0", classify: () => "female-old",
  },
  {
    path: "声音素材", prefix: "BASE", source: "项目现有人物声音", license: "原素材授权待复核",
    filter: (name) => /^people_(male|female)_(young|average|old)\./i.test(name),
    classify(name) {
      if (name.includes("female_young")) return "female-young";
      if (name.includes("female_old")) return "female-old";
      if (name.includes("male_young")) return "male-young";
      return "male-old";
    },
  },
];

const external = [
  { id: "WEB-MY-001", category: "male-young", title: "青年男倾向 · Gibberish", filename: "chat-male-gibberish-cc0.mp3", source: "Freesound / SoundCollectah 109404", tags: ["网络精选", "嘟囔"], scenes: ["chat"] },
  { id: "WEB-MO-001", category: "male-old", title: "老年男倾向 · Deep Mumble", filename: "chat-male-deep-mumble-cc0.mp3", source: "Freesound / dynamique 536967", tags: ["网络精选", "嘟囔"], scenes: ["chat"] },
  { id: "WEB-FY-001", category: "female-young", title: "青年女倾向 · Gibberish", filename: "chat-female-gibberish-cc0.mp3", source: "Freesound / cloyen 800349", tags: ["网络精选", "嘟囔"], scenes: ["chat"] },
  { id: "WEB-FO-001", category: "female-old", title: "老年女倾向 · Wa-Wa Mumble", filename: "chat-female-wawa-cc0.mp3", source: "Freesound / JohnsonBrandEditing 243379", tags: ["网络精选", "嘟囔"], scenes: ["chat"] },

  { id: "WEB-FY-101", category: "female-young", title: "女性 · 无意义碎语 A", filename: "web/fs-238642.mp3", source: "Freesound / mvVoiceActing 238642", tags: ["网络精选", "嘟囔"], scenes: ["chat"] },
  { id: "WEB-FO-101", category: "female-old", title: "女性 · 克制叹气", filename: "web/fs-389992.mp3", source: "Freesound / morganveilleux 389992", tags: ["网络精选", "叹气"], scenes: ["chat", "reject"] },
  { id: "WEB-FY-102", category: "female-young", title: "女性 · 疑问 Hmm", filename: "web/fs-170768.mp3", source: "Freesound / esperar 170768", tags: ["网络精选", "犹豫", "嘟囔"], scenes: ["chat"] },
  { id: "WEB-FY-103", category: "female-young", title: "女性 · 多种 Hmm / Mm-hmm", filename: "web/fs-170766.mp3", source: "Freesound / esperar 170766", tags: ["网络精选", "犹豫", "肯定", "嘟囔"], scenes: ["chat", "approve"] },
  { id: "WEB-FO-102", category: "female-old", title: "女性 · 思考与被说服 Hmm", filename: "web/fs-337082.mp3", source: "Freesound / sterferny 337082", tags: ["网络精选", "犹豫", "肯定"], scenes: ["chat", "approve"] },
  { id: "WEB-FY-104", category: "female-young", title: "女性 · 无意义碎语 B", filename: "web/fs-368384.mp3", source: "Freesound / mvVoiceActing 368384", tags: ["网络精选", "嘟囔"], scenes: ["chat"] },
  { id: "WEB-FY-105", category: "female-young", title: "女性 · 远处含混交谈 A", filename: "web/fs-428071.mp3", source: "Freesound / senshi.sun 428071", tags: ["网络精选", "嘟囔"], scenes: ["chat"] },
  { id: "WEB-FO-103", category: "female-old", title: "女性 · 远处含混交谈 B", filename: "web/fs-428072.mp3", source: "Freesound / senshi.sun 428072", tags: ["网络精选", "嘟囔"], scenes: ["chat"] },

  { id: "WEB-MO-101", category: "male-old", title: "低沉倾向 · 含混耳语与嘟囔", filename: "web/fs-346638.mp3", source: "Freesound / frosthardr 346638", tags: ["网络精选", "嘟囔"], scenes: ["chat"] },
  { id: "WEB-MO-102", category: "male-old", title: "男性 · Oooh / Aaah / Errr", filename: "web/fs-790337.mp3", source: "Freesound / GreasyPlastic 790337", tags: ["网络精选", "犹豫", "嘟囔"], scenes: ["chat", "reject"] },
  { id: "WEB-MY-101", category: "male-young", title: "男性 NPC · Why", filename: "web/fs-801100.mp3", source: "Freesound / Sadiquecat 801100", tags: ["网络精选", "犹豫", "否定"], scenes: ["reject"] },
  { id: "WEB-MY-102", category: "male-young", title: "男性 NPC · Nope", filename: "web/fs-801092.mp3", source: "Freesound / Sadiquecat 801092", tags: ["网络精选", "否定"], scenes: ["reject"] },
  { id: "WEB-MY-103", category: "male-young", title: "男性 NPC · Yes", filename: "web/fs-801296.mp3", source: "Freesound / Sadiquecat 801296", tags: ["网络精选", "肯定"], scenes: ["approve"] },
  { id: "WEB-MY-104", category: "male-young", title: "男性 NPC · Yay", filename: "web/fs-801292.mp3", source: "Freesound / Sadiquecat 801292", tags: ["网络精选", "笑", "肯定"], scenes: ["approve"] },
  { id: "WEB-MY-105", category: "male-young", title: "男性 NPC · No 多版本", filename: "web/fs-801073.mp3", source: "Freesound / Sadiquecat 801073", tags: ["网络精选", "否定"], scenes: ["reject"] },
  { id: "WEB-MY-106", category: "male-young", title: "男性 NPC · Ugh", filename: "web/fs-801094.mp3", source: "Freesound / Sadiquecat 801094", tags: ["网络精选", "叹气", "否定"], scenes: ["reject"] },
  { id: "WEB-MY-107", category: "male-young", title: "男性 NPC · No No No", filename: "web/fs-801076.mp3", source: "Freesound / Sadiquecat 801076", tags: ["网络精选", "否定"], scenes: ["reject"] },
  { id: "WEB-MY-108", category: "male-young", title: "男性 NPC · Naahh", filename: "web/fs-801072.mp3", source: "Freesound / Sadiquecat 801072", tags: ["网络精选", "嘟囔", "否定"], scenes: ["chat", "reject"] },
  { id: "WEB-MY-109", category: "male-young", title: "男性 NPC · Yuck", filename: "web/fs-801101.mp3", source: "Freesound / Sadiquecat 801101", tags: ["网络精选", "否定"], scenes: ["reject"] },
];

function inferTags(filename) {
  const lower = filename.toLowerCase();
  const rules = [
    ["叹气", /sigh/], ["犹豫", /erm|hmm|hm\b|huh|think|what to do|doushio|anno sa/],
    ["嘟囔", /gibberish|mumble|wa-wa/], ["笑", /laugh|cheer|great|wow|good luck/],
    ["哭", /cry/], ["疼痛", /pain|damage|damaged|ouch|ow\b|itai|death|dying/],
    ["肯定", /affirm|yes|yeah|ok\b|alright|definitely|thank|thanks|sou/],
    ["否定", /no\b|never|not happening|objection|no way/],
    ["招呼", /hello|hey|hi\b|howdy|konnichiha|ohayou|what.?s up/],
    ["告别", /bye|goodbye|farewell|fair well|see ya|see you|sayonara|mata ne|take care/],
    ["用力", /grunt|effort|exert|attack|kick|punch|jump|hiyah/], ["空闲", /idle|reaction/],
    ["治愈", /heal|healed|cure/],
    ["台词", /hello|hey|hi\b|bye|thank|yes|no\b|sorry|ready|great|what|good|later|love|game over|way|fire|water|ice|wind|curse|hex|aqua|burn|freeze|tornado|twister|cyclone|blizzard|corruption|bubbles|hellstorm/],
  ];
  const tags = rules.filter(([, pattern]) => pattern.test(lower)).map(([tag]) => tag);
  return tags.length ? [...new Set(tags)] : ["其他"];
}

function inferScenes(tags) {
  const scenes = new Set();
  if (tags.some((tag) => ["嘟囔", "叹气", "犹豫", "招呼", "空闲", "台词"].includes(tag))) scenes.add("chat");
  if (tags.some((tag) => ["笑", "肯定", "治愈", "告别"].includes(tag))) scenes.add("approve");
  if (tags.some((tag) => ["哭", "疼痛", "否定", "用力"].includes(tag))) scenes.add("reject");
  if (scenes.size === 0) scenes.add("chat");
  return [...scenes];
}

async function audioFiles(directory) {
  return (await readdir(directory, { withFileTypes: true }))
    .filter((entry) => entry.isFile() && audioExtensions.has(extname(entry.name).toLowerCase()));
}

await mkdir(outputRoot, { recursive: true });
const voices = [];
const seenHashes = new Set();

for (const group of groups) {
  const directory = join(sourceRoot, group.path);
  let sequence = 0;
  for (const entry of (await audioFiles(directory)).sort((a, b) => a.name.localeCompare(b.name, "en"))) {
    if (group.filter && !group.filter(entry.name)) continue;
    const sourcePath = join(directory, entry.name);
    const bytes = await readFile(sourcePath);
    const hash = createHash("sha256").update(bytes).digest("hex");
    if (seenHashes.has(hash)) continue;
    seenHashes.add(hash);
    sequence += 1;
    const extension = extname(entry.name).toLowerCase();
    const id = `${group.prefix}-${String(sequence).padStart(3, "0")}`;
    const outputName = `${id}${extension}`;
    const tags = inferTags(entry.name);
    await copyFile(sourcePath, new URL(outputName, outputRoot));
    voices.push({
      id, category: group.classify(entry.name), title: entry.name.replace(/\.[^.]+$/, ""),
      file: `library/${outputName}`, description: `标签：${tags.join("、")}。`, tags,
      scenes: inferScenes(tags), source: group.source, source_file: sourcePath, license: group.license,
    });
  }
}

for (const { id, category, title, filename, source, tags, scenes } of external) {
  const input = new URL(`./audio/${filename}`, import.meta.url);
  const bytes = await readFile(input);
  const hash = createHash("sha256").update(bytes).digest("hex");
  if (seenHashes.has(hash)) continue;
  seenHashes.add(hash);
  const outputName = `${id}${extname(filename)}`;
  await copyFile(input, new URL(outputName, outputRoot));
  voices.push({
    id, category, title, file: `library/${outputName}`,
    description: `真实人声候选；适合：${scenes.join(" / ")}。`, tags, scenes,
    source, source_file: input.pathname, license: "CC0",
  });
}

voices.sort((a, b) => a.category.localeCompare(b.category) || a.id.localeCompare(b.id));
await writeFile(manifestPath, `${JSON.stringify({ schema_version: 1, generated_at: new Date().toISOString(), voices }, null, 2)}\n`);
console.log(`Wrote ${voices.length} unique voice assets.`);
