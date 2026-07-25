import { readFile, readdir, stat } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(scriptDirectory, "..");
const outputDirectory = join(projectRoot, "output", "newspaper-7day-samples");
const imageDirectory = join(outputDirectory, "images");
const config = JSON.parse(
  await readFile(join(projectRoot, "data", "narrative", "newspapers.json"), "utf8"),
);
const manifest = JSON.parse(await readFile(join(outputDirectory, "manifest.json"), "utf8"));
const html = await readFile(join(outputDirectory, "index.html"), "utf8");

const assert = (condition, message) => {
  if (!condition) throw new Error(message);
};

const publisherSlug = (publisher) =>
  publisher.id.toLowerCase().replace(/^newspaper-/, "").replaceAll("-", "_");

assert(config.publishers.length === 4, "configuration must contain four publishers");
assert(manifest.count === 28, "manifest must contain 28 samples");
assert(manifest.samples.length === 28, "manifest samples must contain 28 entries");

const expectedFilenames = [];
for (let day = 1; day <= 7; day += 1) {
  const daySamples = manifest.samples.filter((sample) => sample.day === day);
  assert(daySamples.length === 4, `day ${day} must contain four samples`);

  for (const publisher of config.publishers) {
    const issue = publisher.issues.find((entry) => entry.day === day);
    assert(issue, `${publisher.id} must define day ${day}`);
    const filename = `day-${String(day).padStart(2, "0")}-${publisherSlug(publisher)}.png`;
    const imagePath = join(imageDirectory, filename);
    const buffer = await readFile(imagePath);
    assert(buffer.length > 24, `${filename} must be a non-empty PNG`);
    assert(buffer.subarray(1, 4).toString("ascii") === "PNG", `${filename} must use PNG format`);
    assert(buffer.readUInt32BE(16) === 700, `${filename} must be 700 px wide`);
    assert(buffer.readUInt32BE(20) === 1050, `${filename} must be 1050 px high`);

    const sample = daySamples.find((entry) => entry.publisher_id === publisher.id);
    assert(sample, `${filename} must have a manifest entry`);
    assert(sample.headline === issue.headline, `${filename} headline must match configuration`);
    assert(sample.article === issue.article, `${filename} article must match configuration`);
    assert(sample.reflection === issue.reflection, `${filename} reflection must match configuration`);
    assert(html.includes(`images/${filename}`), `${filename} must appear in the HTML gallery`);
    expectedFilenames.push(filename);
  }
}

const actualFilenames = (await readdir(imageDirectory))
  .filter((filename) => filename.endsWith(".png"))
  .sort();
assert(actualFilenames.length === 28, "image directory must contain exactly 28 PNG samples");
assert(
  JSON.stringify(actualFilenames) === JSON.stringify(expectedFilenames.sort()),
  "image directory filenames must match the seven-day configuration",
);

const contactSheet = await stat(join(outputDirectory, "contact-sheet.png"));
assert(contactSheet.isFile() && contactSheet.size > 0, "contact sheet must exist");
assert(html.includes("28 SAMPLES"), "HTML gallery must declare the complete sample count");

process.stdout.write(
  `FORMOCRACY_NEWSPAPER_7DAY_SAMPLES_OK publishers=4 days=7 samples=${manifest.samples.length}\n`,
);
