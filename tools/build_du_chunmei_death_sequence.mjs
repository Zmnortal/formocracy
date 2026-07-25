import { mkdir, copyFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const sharp = require("sharp");

const toolDirectory = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(toolDirectory, "..");
const outputDirectory = join(
  projectRoot,
  "assets",
  "narrative",
  "events",
  "du_chunmei_death",
  "frames",
);
const eventDirectory = dirname(outputDirectory);

const background = (name) => join(projectRoot, "assets", name);
const duFrame = (name) =>
  join(
    projectRoot,
    "assets",
    "characters",
    "applicants",
    "person_du",
    "fullbody_frames_20",
    name,
  );

const sources = {
  service: background("office/background/clean_service_window.png"),
  hall: background("opening/first_day_intro/01_empty_hall.png"),
  home: background("life/interiors/home_12c.png"),
  corridor: background(
    "office/transitions/after_work_corridor/corridor_walk_03_stop.png",
  ),
  envelope: background("documents/envelopes/bureau_envelope_closed.png"),
  medical: background("documents/templates/medical_receipt.png"),
  water: background("menu/document_collage/final/06_water_quota.png"),
};

async function cover(path, zoom = 1, position = "centre") {
  return sharp(path)
    .resize(Math.round(1280 * zoom), Math.round(720 * zoom), {
      fit: "cover",
      position,
    })
    .extract({
      left: Math.max(0, Math.round((1280 * zoom - 1280) / 2)),
      top: Math.max(0, Math.round((720 * zoom - 720) / 2)),
      width: 1280,
      height: 720,
    })
    .png()
    .toBuffer();
}

async function actor(path, width, left, top, opacity = 1) {
  const image = sharp(path).resize({ width });
  if (opacity < 1) image.ensureAlpha().linear(1, 0).joinChannel(
    await sharp({
      create: {
        width,
        height: Math.round(width * 1.5),
        channels: 1,
        background: Math.round(255 * opacity),
      },
    }).png().toBuffer(),
  );
  return { input: await image.png().toBuffer(), left, top };
}

async function paper(path, width, angle, left, top) {
  return {
    input: await sharp(path)
      .resize({ width })
      .rotate(angle, { background: { r: 0, g: 0, b: 0, alpha: 0 } })
      .png()
      .toBuffer(),
    left,
    top,
  };
}

async function makeFrame(number, base, layers = []) {
  const filename = `du-death-${String(number).padStart(2, "0")}.png`;
  const destination = join(outputDirectory, filename);
  await sharp(base).composite(layers).png().toFile(destination);
  return destination;
}

await mkdir(outputDirectory, { recursive: true });

const frames = [];
frames.push(
  await makeFrame(
    1,
    await cover(sources.service, 1.0),
    [
      await actor(
        duFrame("05_nervous_protect_documents_fullbody.png"),
        286,
        500,
        160,
      ),
    ],
  ),
);
frames.push(
  await makeFrame(
    2,
    await cover(sources.service, 1.08),
    [
      await actor(
        duFrame("14_reject_show_medical_evidence_fullbody.png"),
        342,
        468,
        124,
      ),
    ],
  ),
);
frames.push(
  await makeFrame(
    3,
    await cover(sources.hall, 1.0),
    [
      await actor(
        duFrame("15_reject_resolved_fullbody.png"),
        224,
        812,
        210,
      ),
    ],
  ),
);
frames.push(
  await makeFrame(
    4,
    await cover(sources.hall, 1.06),
    [
      await actor(
        duFrame("19_exit_rejected_step_a_fullbody.png"),
        186,
        928,
        252,
      ),
    ],
  ),
);
frames.push(
  await makeFrame(5, await cover(sources.corridor, 1.12, "east")),
);
frames.push(
  await makeFrame(
    6,
    await cover(sources.home, 1.0),
    [
      await paper(sources.envelope, 184, -6, 778, 482),
      await paper(sources.medical, 210, 4, 520, 426),
    ],
  ),
);
frames.push(
  await makeFrame(
    7,
    await cover(sources.home, 1.22, "south"),
    [
      await paper(sources.water, 240, -8, 432, 348),
      await paper(sources.medical, 260, 5, 664, 328),
      await paper(sources.envelope, 224, -2, 808, 474),
    ],
  ),
);
frames.push(
  await makeFrame(8, await cover(sources.service, 1.18)),
);

await copyFile(frames[4], join(eventDirectory, "clinic_window.png"));
await copyFile(frames[6], join(eventDirectory, "belongings.png"));

process.stdout.write(
  `${JSON.stringify({ outputDirectory, frames }, null, 2)}\n`,
);
