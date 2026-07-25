import { mkdir, readFile, stat, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(scriptDirectory, "..");
const configPath = join(projectRoot, "data", "narrative", "newspapers.json");
const outputDirectory = join(projectRoot, "output", "newspaper-7day-samples");
const imageDirectory = join(outputDirectory, "images");
const config = JSON.parse(await readFile(configPath, "utf8"));

const escapeHtml = (value) =>
  String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");

const slug = (publisher) =>
  publisher.id.toLowerCase().replace(/^newspaper-/, "").replaceAll("-", "_");

const samples = [];
for (let day = 1; day <= 7; day += 1) {
  for (const publisher of config.publishers) {
    const issue = publisher.issues.find((entry) => entry.day === day);
    if (!issue) throw new Error(`Missing ${publisher.id} day ${day}`);
    const filename = `day-${String(day).padStart(2, "0")}-${slug(publisher)}.png`;
    const path = join(imageDirectory, filename);
    const file = await stat(path);
    if (!file.isFile() || file.size === 0) throw new Error(`Missing rendered sample: ${path}`);
    samples.push({
      day,
      publisher_id: publisher.id,
      publisher_name: publisher.name,
      voice: publisher.voice,
      accent: `#${publisher.accent}`,
      headline: issue.headline,
      teaser: issue.teaser,
      article: issue.article,
      reflection: issue.reflection,
      image: `images/${filename}`,
    });
  }
}
if (samples.length !== 28) throw new Error(`Expected 28 samples, received ${samples.length}`);

const daySections = Array.from({ length: 7 }, (_, index) => index + 1)
  .map((day) => {
    const cards = samples
      .filter((sample) => sample.day === day)
      .map(
        (sample) => `
          <article class="paper-card" style="--accent:${sample.accent}">
            <button class="paper-open" type="button" data-image="${sample.image}" data-title="${escapeHtml(sample.publisher_name)} · 第 ${day} 天">
              <img src="${sample.image}" alt="${escapeHtml(sample.publisher_name)}第 ${day} 天头版样张">
            </button>
            <div class="paper-copy">
              <div class="paper-meta"><span>${escapeHtml(sample.publisher_name)}</span><b>DAY ${String(day).padStart(2, "0")}</b></div>
              <h3>${escapeHtml(sample.headline)}</h3>
              <p>${escapeHtml(sample.teaser)}</p>
              <blockquote>${escapeHtml(sample.reflection)}</blockquote>
            </div>
          </article>`,
      )
      .join("");
    return `
      <section class="day-section" id="day-${day}">
        <header class="day-header">
          <span>WORKDAY / ${String(day).padStart(2, "0")}</span>
          <h2>第 ${day} 天 · 四家报纸头版</h2>
          <p>同一座城市，同一天，四种不同的叙述角度。</p>
        </header>
        <div class="paper-grid">${cards}</div>
      </section>`;
  })
  .join("");

const navigation = Array.from({ length: 7 }, (_, index) => index + 1)
  .map((day) => `<a href="#day-${day}">第 ${day} 天</a>`)
  .join("");

const html = `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>FORMOCRACY · 7 天报纸样张</title>
  <style>
    :root{color-scheme:dark;--ink:#ddd4b8;--muted:#858b7a;--line:#30382f;--panel:#0d110f;--bg:#060806}
    *{box-sizing:border-box}
    html{scroll-behavior:smooth}
    body{margin:0;background:radial-gradient(circle at 50% 0,#17201a 0,#090c09 34%,var(--bg) 70%);color:var(--ink);font-family:"Songti SC","Noto Serif CJK SC",serif}
    body:before{content:"";position:fixed;inset:0;pointer-events:none;opacity:.08;background-image:repeating-linear-gradient(0deg,transparent 0 3px,#fff 4px)}
    .masthead{padding:54px 5vw 36px;border-bottom:1px solid var(--line);background:#080b09e8}
    .eyebrow{font:700 11px/1.2 ui-monospace,monospace;letter-spacing:.22em;color:#a88852}
    h1{margin:14px 0 10px;font-size:clamp(30px,5vw,68px);font-weight:500;letter-spacing:.05em}
    .masthead p{max-width:760px;margin:0;color:var(--muted);line-height:1.8}
    .day-nav{position:sticky;top:0;z-index:20;display:flex;gap:8px;overflow:auto;padding:12px 5vw;background:#070a08e8;backdrop-filter:blur(12px);border-bottom:1px solid var(--line)}
    .day-nav a{flex:0 0 auto;padding:8px 14px;border:1px solid #3f493d;color:#b9bca6;text-decoration:none;font:12px ui-monospace,monospace}
    .day-nav a:hover{color:#fff;border-color:#a88852;background:#1a1e16}
    main{width:min(1480px,94vw);margin:auto;padding-bottom:100px}
    .day-section{padding:70px 0 20px;scroll-margin-top:62px}
    .day-header{display:grid;grid-template-columns:160px 1fr auto;gap:18px;align-items:end;padding-bottom:18px;border-bottom:1px solid var(--line)}
    .day-header span{color:#a88852;font:12px ui-monospace,monospace;letter-spacing:.14em}
    .day-header h2{margin:0;font-size:28px;font-weight:500}
    .day-header p{margin:0;color:var(--muted);font-size:13px}
    .paper-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:22px;padding-top:24px}
    .paper-card{min-width:0;background:linear-gradient(180deg,#141814,#0b0e0c);border:1px solid #30372f;box-shadow:0 18px 40px #0008}
    .paper-open{display:block;width:100%;padding:12px;border:0;background:#020302;cursor:zoom-in}
    .paper-open img{display:block;width:100%;height:auto;aspect-ratio:2/3;object-fit:cover;border:1px solid color-mix(in srgb,var(--accent) 54%,#242820)}
    .paper-open:hover img{filter:brightness(1.08);outline:2px solid var(--accent);outline-offset:-3px}
    .paper-copy{padding:16px 18px 20px;border-top:3px solid var(--accent)}
    .paper-meta{display:flex;justify-content:space-between;gap:12px;color:var(--muted);font:10px ui-monospace,monospace;letter-spacing:.08em}
    .paper-meta span{color:var(--accent)}
    .paper-copy h3{min-height:3em;margin:12px 0 8px;font-size:17px;line-height:1.5;font-weight:600}
    .paper-copy p{min-height:3.5em;margin:0;color:#a6aa9b;font-size:12px;line-height:1.7}
    blockquote{margin:14px 0 0;padding:10px 12px;border-left:2px solid var(--accent);background:#050705;color:#c5bda5;font-size:12px;line-height:1.7}
    dialog{width:min(820px,92vw);padding:0;border:1px solid #6b674f;background:#070907;color:var(--ink);box-shadow:0 40px 100px #000}
    dialog::backdrop{background:#000d;backdrop-filter:blur(5px)}
    .dialog-bar{display:flex;justify-content:space-between;align-items:center;padding:12px 16px;border-bottom:1px solid var(--line);font:12px ui-monospace,monospace}
    .dialog-bar button{border:1px solid #555b4c;background:#10140f;color:#d9d1b6;padding:7px 12px;cursor:pointer}
    dialog img{display:block;width:100%;max-height:82vh;object-fit:contain;background:#020302}
    footer{padding:28px 5vw 46px;border-top:1px solid var(--line);color:#666e61;font:11px ui-monospace,monospace;text-align:center}
    @media(max-width:1100px){.paper-grid{grid-template-columns:repeat(2,1fr)}.day-header{grid-template-columns:1fr}.day-header p{display:none}}
    @media(max-width:620px){.paper-grid{grid-template-columns:1fr}.masthead{padding-top:36px}}
  </style>
</head>
<body>
  <header class="masthead">
    <div class="eyebrow">FORMOCRACY / NEWSPAPER NARRATIVE ARCHIVE</div>
    <h1>七日新闻叙事样张</h1>
    <p>共 28 张正式头版：衡川日报、十二区晨讯、衡川行政公报与旧城晚报。所有内容直接来自游戏配置，并使用游戏内安全网格渲染。</p>
  </header>
  <nav class="day-nav">${navigation}</nav>
  <main>${daySections}</main>
  <dialog id="preview">
    <div class="dialog-bar"><span id="preview-title"></span><button type="button">关闭</button></div>
    <img id="preview-image" alt="报纸大图预览">
  </dialog>
  <footer>FORMOCRACY · 第十二区新闻叙事档案 · 28 SAMPLES</footer>
  <script>
    const dialog=document.querySelector("#preview");
    const image=document.querySelector("#preview-image");
    const title=document.querySelector("#preview-title");
    document.querySelectorAll(".paper-open").forEach(button=>button.addEventListener("click",()=>{
      image.src=button.dataset.image;
      title.textContent=button.dataset.title;
      dialog.showModal();
    }));
    dialog.querySelector("button").addEventListener("click",()=>dialog.close());
    dialog.addEventListener("click",event=>{if(event.target===dialog)dialog.close()});
  </script>
</body>
</html>`;

await mkdir(outputDirectory, { recursive: true });
await writeFile(join(outputDirectory, "index.html"), html, "utf8");
await writeFile(
  join(outputDirectory, "manifest.json"),
  `${JSON.stringify({ title: "FORMOCRACY 七日新闻叙事样张", count: samples.length, samples }, null, 2)}\n`,
  "utf8",
);

process.stdout.write(
  `${JSON.stringify({ output: join(outputDirectory, "index.html"), samples: samples.length }, null, 2)}\n`,
);
