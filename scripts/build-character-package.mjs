import {
  cp,
  copyFile,
  mkdir,
  readdir,
  readFile,
  rename,
  rm,
  stat,
  writeFile,
} from "node:fs/promises";
import { createHash } from "node:crypto";
import { execFile } from "node:child_process";
import { basename, dirname, extname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import vm from "node:vm";

const execFileAsync = promisify(execFile);
const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(scriptDirectory, "..");
const outputParent = join(projectRoot, "output", "character-package");
const packageName = "formocracy-character-library";
const packageDirectory = join(outputParent, packageName);
const stagingDirectory = join(outputParent, `${packageName}.building`);
const archivePath = join(outputParent, `${packageName}.zip`);
const dossierSourcePath = join(
  projectRoot,
  "output",
  "character-dossier",
  "formocracy-character-dossier-v2.html",
);
const secretarySourceDirectory = join(dirname(dossierSourcePath), "secretary");
const ontologyPath = join(projectRoot, "data", "ontology", "people.json");

const resourcePath = (value) => {
  if (!value?.startsWith("res://")) {
    throw new Error(`Expected a res:// path, received: ${value}`);
  }
  return join(projectRoot, value.slice("res://".length));
};

const characterSlug = (id) => id.toLowerCase().replaceAll("-", "_");
const json = (value) => `${JSON.stringify(value, null, 2)}\n`;

async function assertFile(path) {
  const file = await stat(path);
  if (!file.isFile()) throw new Error(`Expected file: ${path}`);
}

async function copyRequired(source, destination) {
  await assertFile(source);
  await mkdir(dirname(destination), { recursive: true });
  await copyFile(source, destination);
}

async function sha256(path) {
  return createHash("sha256").update(await readFile(path)).digest("hex");
}

async function listFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) files.push(...(await listFiles(path)));
    if (entry.isFile()) files.push(path);
  }
  return files.sort((a, b) => a.localeCompare(b, "en"));
}

function extractDossierPeople(html) {
  const startMarker = "const people=";
  const endMarker = ";\nconst avatarPath=";
  const start = html.indexOf(startMarker);
  const end = html.indexOf(endMarker, start);
  if (start < 0 || end < 0) {
    throw new Error("Unable to locate the embedded dossier people array.");
  }
  const expression = html.slice(start + startMarker.length, end);
  const people = vm.runInNewContext(`(${expression})`, Object.create(null));
  if (!Array.isArray(people)) throw new Error("Dossier people data is not an array.");
  return { people, start, end };
}

function portableDossierHtml(sourceHtml, dossierPeople, start, end) {
  const portablePeople = dossierPeople.map((person) => {
    const slug = characterSlug(person.id);
    return {
      ...person,
      package_slug: slug,
      image: `characters/${slug}/concept.png`,
    };
  });
  const peopleDeclaration = `const people=${JSON.stringify(portablePeople)}`
  let html =
    sourceHtml.slice(0, start) +
    peopleDeclaration +
    sourceHtml.slice(end);

  html = html.replace(
    /const avatarPath=.*?;\nconst standardPortraitPath=.*?;\n/,
    [
      "const packageDir=p=>`characters/${p.package_slug}`;",
      "const avatarPath=p=>`${packageDir(p)}/portrait_8bit.png`;",
      "const standardPortraitPath=p=>`${packageDir(p)}/portrait_standard.png`;",
      "",
    ].join("\n"),
  );
  html = html.replace(
    "      <div class=\"palette\">",
    [
      "      <div class=\"package-links\"><b>PACKAGE FILES / 独立素材</b>",
      "        <span><a href=\"${packageDir(p)}/metadata.json\">JSON</a> · <a href=\"${packageDir(p)}/portrait_standard.png\">PORTRAIT</a> · <a href=\"${packageDir(p)}/fullbody.png\">FULLBODY</a> · <a href=\"${packageDir(p)}/animation_table.json\">ANIMATION</a></span>",
      "      </div>",
      "      <div class=\"palette\">",
    ].join("\n"),
  );
  html = html.replace(
    "    .palette{",
    [
      "    .package-links{margin-top:2.5mm;border-top:1px solid #aaa39a;padding-top:2mm;font-size:7px;line-height:1.5}",
      "    .package-links b{display:block;font:700 6px/1.3 Arial,sans-serif;letter-spacing:.13em;color:#77716a}",
      "    .package-links span{display:block;margin-top:1mm}",
      "    .package-links a{color:var(--accent);text-decoration:none;font-weight:700}",
      "    .palette{",
    ].join("\n"),
  );
  html = html
    .replace("<title>衡川市第十二区人物档案 V2</title>", "<title>FORMOCRACY 人物素材库</title>")
    .replace("CHARACTER DOSSIER · V2", "CHARACTER ASSET LIBRARY")
    .replace("EDITION 02 · 21 PAGES", "OFFLINE PACKAGE · 18 CHARACTERS + SECRETARY");
  return html;
}

async function buildCharacter(ontologyPerson, dossierPerson) {
  const slug = characterSlug(ontologyPerson.id);
  const personDirectory = join(stagingDirectory, "characters", slug);
  const framesDirectory = join(personDirectory, "frames");
  await mkdir(framesDirectory, { recursive: true });

  const portraitPackagePath =
    `assets/characters/portraits_8bit/${slug}.png`;
  const portraitSource = join(projectRoot, portraitPackagePath);
  const standardPortraitPackagePath =
    `assets/characters/portraits_standard/${slug}.png`;
  const standardPortraitSource = join(projectRoot, standardPortraitPackagePath);
  const actorSource = resourcePath(ontologyPerson.actor_texture);
  const standardPortraitFrameSource = join(
    dirname(actorSource),
    "01_queue_idle_neutral_fullbody.png",
  );
  const animationSource = resourcePath(ontologyPerson.animation_table);
  const conceptSource = resolve(dirname(dossierSourcePath), dossierPerson.image);

  await assertFile(standardPortraitFrameSource);
  await copyRequired(portraitSource, join(personDirectory, "portrait_8bit.png"));
  await copyRequired(
    standardPortraitSource,
    join(personDirectory, "portrait_standard.png"),
  );
  await copyRequired(conceptSource, join(personDirectory, "concept.png"));
  await copyRequired(actorSource, join(personDirectory, "fullbody.png"));

  const animation = JSON.parse(await readFile(animationSource, "utf8"));
  const frameSources = new Map();
  const rememberFrame = (source) => {
    if (!source) return;
    const absolute = resolve(dirname(animationSource), source);
    frameSources.set(basename(absolute), absolute);
  };
  rememberFrame(animation.static_actor_texture);
  for (const action of animation.actions ?? []) {
    for (const frame of action.frames ?? []) rememberFrame(frame);
  }
  frameSources.set(basename(actorSource), actorSource);

  for (const [filename, source] of frameSources) {
    await copyRequired(source, join(framesDirectory, filename));
  }

  const portableAnimation = structuredClone(animation);
  if (portableAnimation.static_actor_texture) {
    portableAnimation.static_actor_texture =
      `frames/${basename(resolve(dirname(animationSource), portableAnimation.static_actor_texture))}`;
  }
  for (const action of portableAnimation.actions ?? []) {
    action.frames = (action.frames ?? []).map(
      (frame) => `frames/${basename(resolve(dirname(animationSource), frame))}`,
    );
  }
  await writeFile(
    join(personDirectory, "animation_table.json"),
    json(portableAnimation),
    "utf8",
  );

  let voiceFilename = null;
  if (ontologyPerson.voice_sfx) {
    const voiceSource = resourcePath(ontologyPerson.voice_sfx);
    voiceFilename = `voice_sfx${extname(voiceSource).toLowerCase() || ".wav"}`;
    await copyRequired(voiceSource, join(personDirectory, voiceFilename));
  }

  const metadata = {
    schema_version: 1,
    id: ontologyPerson.id,
    slug,
    identity: {
      display_name: ontologyPerson.display_name,
      latin_name: dossierPerson.latin,
      age: ontologyPerson.age,
      occupation: ontologyPerson.occupation,
      citizen_id: ontologyPerson.citizen_id,
      queue_label: ontologyPerson.queue_label,
    },
    narrative: {
      file_number: dossierPerson.file,
      role: dossierPerson.role,
      summary: dossierPerson.who,
      background: dossierPerson.story,
      quote: dossierPerson.quote,
    },
    administrative: {
      status: dossierPerson.status,
      code: dossierPerson.code,
      origin: dossierPerson.origin,
      registry: ontologyPerson.registry,
      actual_residence: ontologyPerson.actual_residence,
      identity_document: dossierPerson.idDoc,
      residence_document: dossierPerson.resDoc,
      policy_risk: dossierPerson.risk,
    },
    gameplay: {
      administrative_status: ontologyPerson.administrative_status,
      actor_scale: ontologyPerson.actor_scale,
      move_speed: ontologyPerson.move_speed,
    },
    visual: {
      colors: {
        primary: dossierPerson.color,
        secondary: dossierPerson.secondary,
        forbidden: dossierPerson.forbidden,
      },
      portrait_specification: {
        logical_size: "32x32",
        output_size: "128x128",
        palette: ["#000000", "#FFFFFF"],
        bit_depth: 1,
        scaling: "nearest-neighbor",
      },
      standard_portrait_specification: {
        output_size: "256x256",
        source: "01_queue_idle_neutral_fullbody",
        crop: "head-and-shoulders",
        background: "transparent",
      },
    },
    assets: {
      portrait_8bit: "portrait_8bit.png",
      portrait_standard: "portrait_standard.png",
      concept_art: "concept.png",
      fullbody: "fullbody.png",
      animation_table: "animation_table.json",
      animation_frames: {
        directory: "frames",
        count: frameSources.size,
      },
      voice_sfx: voiceFilename,
    },
    original_project_paths: {
      portrait_texture: ontologyPerson.portrait_texture,
      packaged_portrait_source: `res://${portraitPackagePath}`,
      standard_portrait_texture: ontologyPerson.standard_portrait_texture,
      packaged_standard_portrait_source: `res://${standardPortraitPackagePath}`,
      standard_portrait_source_frame:
        `res://${relative(projectRoot, standardPortraitFrameSource)}`,
      actor_texture: ontologyPerson.actor_texture,
      animation_table: ontologyPerson.animation_table,
      voice_sfx: ontologyPerson.voice_sfx ?? null,
    },
  };
  await writeFile(join(personDirectory, "metadata.json"), json(metadata), "utf8");

  const files = await listFiles(personDirectory);
  const checksums = {};
  for (const file of files) {
    checksums[relative(personDirectory, file)] = await sha256(file);
  }
  return {
    id: ontologyPerson.id,
    slug,
    display_name: ontologyPerson.display_name,
    age: ontologyPerson.age,
    occupation: ontologyPerson.occupation,
    directory: `characters/${slug}`,
    metadata: `characters/${slug}/metadata.json`,
    portrait: `characters/${slug}/portrait_8bit.png`,
    standard_portrait: `characters/${slug}/portrait_standard.png`,
    concept: `characters/${slug}/concept.png`,
    fullbody: `characters/${slug}/fullbody.png`,
    animation_table: `characters/${slug}/animation_table.json`,
    voice_sfx: voiceFilename ? `characters/${slug}/${voiceFilename}` : null,
    frame_count: frameSources.size,
    checksums,
  };
}

async function main() {
  await mkdir(outputParent, { recursive: true });
  await rm(stagingDirectory, { recursive: true, force: true });
  await rm(packageDirectory, { recursive: true, force: true });
  await rm(archivePath, { force: true });
  await mkdir(stagingDirectory, { recursive: true });

  const ontologyPeople = JSON.parse(await readFile(ontologyPath, "utf8"));
  const dossierHtml = await readFile(dossierSourcePath, "utf8");
  const extracted = extractDossierPeople(dossierHtml);
  const dossierById = new Map(extracted.people.map((person) => [person.id, person]));

  if (ontologyPeople.length !== 18 || extracted.people.length !== 18) {
    throw new Error(
      `Expected 18 characters, received ontology=${ontologyPeople.length}, dossier=${extracted.people.length}`,
    );
  }

  const characters = [];
  for (const ontologyPerson of ontologyPeople) {
    const dossierPerson = dossierById.get(ontologyPerson.id);
    if (!dossierPerson) throw new Error(`Missing dossier entry: ${ontologyPerson.id}`);
    characters.push(await buildCharacter(ontologyPerson, dossierPerson));
  }

  const portableHtml = portableDossierHtml(
    dossierHtml,
    extracted.people,
    extracted.start,
    extracted.end,
  );
  await writeFile(join(stagingDirectory, "index.html"), portableHtml, "utf8");
  await cp(secretarySourceDirectory, join(stagingDirectory, "secretary"), {
    recursive: true,
  });

  const contactSheetSource = join(projectRoot, "tmp", "avatar-audit", "nes-all-18-v2.png");
  await copyRequired(contactSheetSource, join(stagingDirectory, "contact-sheet.png"));

  const manifest = {
    schema_version: 1,
    title: "FORMOCRACY 人物素材库",
    character_count: characters.length,
    package_root: packageName,
    entrypoint: "index.html",
    contents: {
      per_character_metadata: true,
      separated_images: true,
      standard_portraits: true,
      animation_frames: true,
      voice_sfx: true,
      secretary_dossier: true,
      offline_html: true,
    },
    characters,
  };
  await writeFile(join(stagingDirectory, "manifest.json"), json(manifest), "utf8");

  const totalFrames = characters.reduce((sum, character) => sum + character.frame_count, 0);
  const readme = `# FORMOCRACY 人物素材库

打开 \`index.html\` 可离线浏览 18 位人物与特殊叙事实体“秘书”的统合档案。

## 目录结构

- \`index.html\`：统合人物档案，无需服务器。
- \`manifest.json\`：全包机器可读清单。
- \`contact-sheet.png\`：18 位人物 8-bit 头像总览。
- \`secretary/\`：秘书四态 128×128 蒙版、透明高分辨率图、源图与原始预览页。
- \`SHA256SUMS.txt\`：包内文件完整性校验。
- \`characters/<人物 slug>/\`：每位人物的独立素材目录。

每个人物目录包含：

- \`metadata.json\`：身份、叙事、行政、玩法、视觉与源路径元数据。
- \`portrait_standard.png\`：256×256、由全身图头肩区域统一裁切的透明背景标准头像。
- \`portrait_8bit.png\`：128×128、纯黑白、1-bit 头像。
- \`concept.png\`：人物设定图。
- \`fullbody.png\`：游戏内默认全身像。
- \`animation_table.json\`：已改写为包内相对路径的动画表。
- \`frames/*.png\`：该人物动画表引用的独立帧。
- \`voice_sfx.*\`：当前人物绑定的语音音效。

人物数量：${characters.length}
动画帧文件数量：${totalFrames}
`;
  await writeFile(join(stagingDirectory, "README.md"), readme, "utf8");

  const packageFiles = (await listFiles(stagingDirectory)).filter(
    (path) => basename(path) !== "SHA256SUMS.txt",
  );
  const checksumLines = [];
  for (const file of packageFiles) {
    checksumLines.push(`${await sha256(file)}  ${relative(stagingDirectory, file)}`);
  }
  await writeFile(
    join(stagingDirectory, "SHA256SUMS.txt"),
    `${checksumLines.join("\n")}\n`,
    "utf8",
  );

  await rename(stagingDirectory, packageDirectory);
  await execFileAsync("zip", ["-rq", archivePath, packageName], { cwd: outputParent });

  const archiveStat = await stat(archivePath);
  process.stdout.write(
    json({
      package_directory: packageDirectory,
      archive: archivePath,
      archive_bytes: archiveStat.size,
      characters: characters.length,
      animation_frames: totalFrames,
    }),
  );
}

await main();
