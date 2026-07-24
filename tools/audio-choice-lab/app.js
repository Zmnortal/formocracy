const PEOPLE_URL = "../../data/ontology/people.json";
const STORAGE_KEY = "formocracy-voice-casting-v3";
const LEGACY_STORAGE_KEY = "formocracy-voice-casting-v2";
const SCENES = ["chat", "approve", "reject"];
const sceneLabels = {
  chat: "聊天 / 普通",
  approve: "Approve / 开心",
  reject: "Reject / 驳回",
};

let voices = [];

const categoryLabels = {
  "male-young":"青年男", "male-old":"老年男",
  "female-young":"青年女", "female-old":"老年女",
};
const genderByPerson = {
  "PERSON-LIN":"male", "PERSON-ZHOU":"male", "PERSON-XU":"female", "PERSON-MENG":"female",
  "PERSON-HE":"female", "PERSON-DU":"female", "PERSON-GU":"male", "PERSON-SHEN":"female",
  "PERSON-TANG":"male", "PERSON-LUO":"female", "PROPRIETOR-ZHOU":"female",
  "PROPRIETOR-HE":"male", "PERSON-FANG":"female", "PERSON-LI":"female",
  "PERSON-WEI":"female", "PERSON-JIANG":"male", "PERSON-SONG":"male", "PERSON-YE":"female",
};

let data = loadData();
let people = [];
let activePersonId = null;
let activeVoiceFilter = "all";
let characterFilter = "all";
let activeScene = "chat";
let activeTag = new URLSearchParams(window.location.search).get("tag") || "all";
let searchQuery = "";
let quickPreview = null;
let quickPreviewButton = null;

const el = (selector) => document.querySelector(selector);
const voiceById = (id) => voices.find((voice) => voice.id === id);
const currentPerson = () => people.find((person) => person.id === activePersonId);

function loadData() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY));
    if (saved) return saved;
    const legacy = JSON.parse(localStorage.getItem(LEGACY_STORAGE_KEY));
    if (!legacy) return { assignments:{}, favorites:{}, notes:{} };
    const assignments = {};
    for (const [personId, voiceId] of Object.entries(legacy.assignments || {})) {
      assignments[personId] = { chat: voiceId };
    }
    return { assignments, favorites:legacy.favorites || {}, notes:{} };
  } catch {
    return { assignments:{}, favorites:{}, notes:{} };
  }
}
function saveData() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
  renderSummary();
}
function portraitUrl(path) {
  return path.startsWith("res://") ? `../../${path.slice(6)}` : path;
}
function ageBand(person) {
  return person.age >= 45 ? "old" : "young";
}
function suggestedCategory(person) {
  return `${genderByPerson[person.id] || "female"}-${ageBand(person)}`;
}
function showStatus(message) {
  el("#status").textContent = message;
  el("#status").classList.add("visible");
  clearTimeout(showStatus.timer);
  showStatus.timer = setTimeout(() => el("#status").classList.remove("visible"), 1800);
}
function pauseOthers(current) {
  stopQuickPreview();
  document.querySelectorAll("audio").forEach((audio) => {
    if (audio !== current) audio.pause();
  });
}
function stopQuickPreview() {
  if (quickPreview) {
    quickPreview.pause();
    quickPreview.currentTime = 0;
  }
  if (quickPreviewButton) {
    quickPreviewButton.classList.remove("playing");
    quickPreviewButton.textContent = "▶ 快速试听";
  }
  quickPreview = null;
  quickPreviewButton = null;
}
function switchScene(scene) {
  stopQuickPreview();
  activeScene = scene;
  document.querySelectorAll("#sceneSelector button").forEach((button) => {
    button.classList.toggle("active", button.dataset.scene === scene);
  });
  renderAll();
}
function playQuickPreview(voice, button) {
  if (quickPreviewButton === button && quickPreview && !quickPreview.paused) {
    stopQuickPreview();
    return;
  }
  stopQuickPreview();
  document.querySelectorAll("audio").forEach((audio) => audio.pause());
  quickPreview = new Audio(`audio/${voice.file}`);
  quickPreviewButton = button;
  button.classList.add("playing");
  button.textContent = "■ 停止";
  quickPreview.addEventListener("ended", stopQuickPreview, { once:true });
  quickPreview.addEventListener("error", () => {
    stopQuickPreview();
    showStatus("当前绑定音频无法播放");
  }, { once:true });
  quickPreview.play();
}

function renderSummary() {
  const bound = people.reduce(
    (count, person) => count + SCENES.filter((scene) => data.assignments[person.id]?.[scene]).length,
    0,
  );
  el("#boundCount").textContent = `${bound} / ${people.length * SCENES.length}`;
}
function renderCharacters() {
  const list = el("#characterList");
  list.replaceChildren();
  for (const person of people) {
    const sceneAssignments = data.assignments[person.id] || {};
    const assignedCount = SCENES.filter((scene) => sceneAssignments[scene]).length;
    const card = el("#characterTemplate").content.firstElementChild.cloneNode(true);
    card.dataset.id = person.id;
    card.classList.toggle("active", person.id === activePersonId);
    card.classList.toggle("bound", assignedCount === SCENES.length);
    card.hidden =
      (characterFilter === "bound" && assignedCount !== SCENES.length) ||
      (characterFilter === "unbound" && assignedCount === SCENES.length);
    const image = card.querySelector("img");
    image.src = portraitUrl(person.portrait_texture);
    image.alt = person.display_name;
    card.querySelector("strong").textContent = `${person.queue_label} · ${person.display_name}`;
    card.querySelector(".bio").textContent = `${person.age}岁 · ${person.occupation}`;
    card.querySelector(".binding").textContent = `${assignedCount} / ${SCENES.length} 场景已绑定 · 建议 ${categoryLabels[suggestedCategory(person)]}`;
    card.addEventListener("click", () => {
      activePersonId = person.id;
      activeVoiceFilter = suggestedCategory(person);
      syncFilterButtons();
      renderAll();
    });
    list.append(card);
  }
}
function renderSelectedCharacter() {
  const person = currentPerson();
  if (!person) return;
  el("#selectedPortrait").src = portraitUrl(person.portrait_texture);
  el("#selectedPortrait").alt = person.display_name;
  el("#selectedName").textContent = `${person.queue_label} · ${person.display_name}`;
  el("#selectedMeta").textContent = `${person.age}岁 / ${person.occupation} / 建议 ${categoryLabels[suggestedCategory(person)]}`;
  const assigned = voiceById(data.assignments[person.id]?.[activeScene]);
  el("#currentBinding").textContent = assigned
    ? `${sceneLabels[activeScene]}：${assigned.id} · ${assigned.title}`
    : `${sceneLabels[activeScene]}：尚未绑定声音`;
  el("#unbindVoice").disabled = !assigned;
  const overview = el("#bindingOverview");
  overview.replaceChildren();
  for (const scene of SCENES) {
    const sceneVoice = voiceById(data.assignments[person.id]?.[scene]);
    const row = el("#bindingRowTemplate").content.firstElementChild.cloneNode(true);
    const sceneButton = row.querySelector(".binding-scene");
    sceneButton.textContent = sceneLabels[scene];
    sceneButton.classList.toggle("active", scene === activeScene);
    sceneButton.addEventListener("click", () => switchScene(scene));
    row.querySelector(".binding-voice").textContent = sceneVoice
      ? `${sceneVoice.id} · ${sceneVoice.title}`
      : "尚未绑定";
    const playButton = row.querySelector(".quick-play");
    playButton.disabled = !sceneVoice;
    if (sceneVoice) playButton.addEventListener("click", () => playQuickPreview(sceneVoice, playButton));
    overview.append(row);
  }
}
function renderVoices() {
  const grid = el("#voiceGrid");
  grid.replaceChildren();
  const person = currentPerson();
  const assignedId = person ? data.assignments[person.id]?.[activeScene] : null;
  const query = searchQuery.trim().toLowerCase();
  const visible = voices
    .filter((voice) => activeVoiceFilter === "all" || voice.category === activeVoiceFilter)
    .filter((voice) => activeTag === "all" || voice.tags.includes(activeTag))
    .filter((voice) => !query || [voice.id, voice.title, voice.source, ...voice.tags].join(" ").toLowerCase().includes(query))
    .sort((a, b) => Number(b.scenes.includes(activeScene)) - Number(a.scenes.includes(activeScene)));
  el("#voiceCount").textContent = `${visible.length} / ${voices.length} 条`;

  for (const voice of visible) {
    const card = el("#voiceTemplate").content.firstElementChild.cloneNode(true);
    card.dataset.id = voice.id;
    card.classList.toggle("assigned", voice.id === assignedId);
    card.classList.toggle("favorite-on", Boolean(data.favorites[voice.id]));
    card.querySelector(".voice-id").textContent = voice.id;
    card.querySelector(".category").textContent = categoryLabels[voice.category];
    const fitsScene = voice.scenes.includes(activeScene);
    card.querySelector(".scene-fit").textContent = fitsScene ? `适合${sceneLabels[activeScene]}` : "可试听";
    card.querySelector("h3").textContent = voice.title;
    card.querySelector(".description").textContent = voice.description;
    for (const tag of voice.tags) {
      const tagElement = document.createElement("span");
      tagElement.className = "voice-tag";
      tagElement.textContent = tag;
      card.querySelector(".voice-tags").append(tagElement);
    }
    card.querySelector(".source").textContent = voice.source;
    card.querySelector(".license").textContent = voice.license;
    const audio = card.querySelector("audio");
    audio.src = `audio/${voice.file}`;
    audio.addEventListener("play", () => pauseOthers(audio));

    const favorite = card.querySelector(".favorite");
    favorite.textContent = data.favorites[voice.id] ? "★" : "☆";
    favorite.setAttribute("aria-pressed", String(Boolean(data.favorites[voice.id])));
    favorite.addEventListener("click", () => {
      data.favorites[voice.id] = !data.favorites[voice.id];
      saveData();
      renderVoices();
    });

    const note = card.querySelector(".note");
    note.value = person ? (data.notes[person.id]?.[activeScene]?.[voice.id] || "") : "";
    note.addEventListener("input", () => {
      if (!person) return;
      data.notes[person.id] ||= {};
      data.notes[person.id][activeScene] ||= {};
      data.notes[person.id][activeScene][voice.id] = note.value;
      saveData();
    });

    const assign = card.querySelector(".assign");
    assign.textContent = voice.id === assignedId ? "✓ 已绑定给当前角色" : "绑定给当前角色";
    assign.addEventListener("click", () => {
      if (!person) return;
      data.assignments[person.id] ||= {};
      data.assignments[person.id][activeScene] = voice.id;
      saveData();
      showStatus(`${voice.id} 已绑定给 ${person.display_name} / ${sceneLabels[activeScene]}`);
      renderAll();
    });
    grid.append(card);
  }
}
function renderTagFilters() {
  const container = el("#tagFilters");
  container.replaceChildren();
  const tags = ["all", "网络精选", "叹气", "嘟囔", "犹豫", "空闲", "肯定", "否定", "笑", "哭", "疼痛", "用力", "招呼", "告别", "台词", "其他"];
  for (const tag of tags) {
    const button = document.createElement("button");
    button.className = "tag-filter";
    button.classList.toggle("active", tag === activeTag);
    button.textContent = tag === "all" ? "全部标签" : tag;
    button.addEventListener("click", () => {
      activeTag = tag;
      renderTagFilters();
      renderVoices();
    });
    container.append(button);
  }
}
function syncFilterButtons() {
  document.querySelectorAll(".filter").forEach((button) => {
    button.classList.toggle("active", button.dataset.filter === activeVoiceFilter);
  });
}
function renderAll() {
  renderCharacters();
  renderSelectedCharacter();
  renderTagFilters();
  renderVoices();
  renderSummary();
}

function exportPayload() {
  return {
    schema_version: 2,
    kind: "formocracy_voice_casting",
    exported_at: new Date().toISOString(),
    assignments: people.map((person) => {
      return {
        person_id: person.id,
        queue_label: person.queue_label,
        display_name: person.display_name,
        age: person.age,
        suggested_category: suggestedCategory(person),
        scene_assignments: Object.fromEntries(SCENES.map((scene) => {
          const sceneVoice = voiceById(data.assignments[person.id]?.[scene]);
          return [scene, {
            scene_label: sceneLabels[scene],
            voice_id: sceneVoice?.id || null,
            voice_category: sceneVoice?.category || null,
            voice_title: sceneVoice?.title || null,
            audio_file: sceneVoice ? `tools/audio-choice-lab/audio/${sceneVoice.file}` : null,
            source: sceneVoice?.source || null,
            license: sceneVoice?.license || null,
            note: sceneVoice ? (data.notes[person.id]?.[scene]?.[sceneVoice.id] || "") : "",
          }];
        })),
      };
    }),
    favorite_voice_ids: voices.filter((voice) => data.favorites[voice.id]).map((voice) => voice.id),
  };
}
function downloadJson() {
  const blob = new Blob([JSON.stringify(exportPayload(), null, 2)], { type:"application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `formocracy-voice-casting-${new Date().toISOString().slice(0,10)}.json`;
  anchor.click();
  URL.revokeObjectURL(url);
  showStatus("JSON 已导出");
}

function scoreVoiceForScene(voice, scene) {
  const preferredTags = {
    chat: ["嘟囔", "叹气", "犹豫", "空闲", "招呼"],
    approve: ["肯定", "笑", "治愈", "告别"],
    reject: ["否定", "疼痛", "哭", "用力"],
  };
  let score = voice.scenes.includes(scene) ? 100 : 0;
  for (const [index, tag] of preferredTags[scene].entries()) {
    if (voice.tags.includes(tag)) score += preferredTags[scene].length - index;
  }
  if (voice.license.includes("待复核")) score -= 20;
  if (voice.tags.includes("台词")) score -= 2;
  return score;
}

function autoAssignMissing() {
  const usage = {};
  for (const assignments of Object.values(data.assignments)) {
    for (const voiceId of Object.values(assignments)) usage[voiceId] = (usage[voiceId] || 0) + 1;
  }
  let filled = 0;
  for (const person of people) {
    data.assignments[person.id] ||= {};
    const category = suggestedCategory(person);
    for (const scene of SCENES) {
      if (data.assignments[person.id][scene]) continue;
      const categoryVoices = voices.filter((voice) => voice.category === category);
      const sceneVoices = categoryVoices.filter((voice) => voice.scenes.includes(scene));
      const candidates = (sceneVoices.length ? sceneVoices : categoryVoices)
        .sort((a, b) => {
          const scoreDifference = scoreVoiceForScene(b, scene) - scoreVoiceForScene(a, scene);
          if (scoreDifference !== 0) return scoreDifference;
          const usageDifference = (usage[a.id] || 0) - (usage[b.id] || 0);
          return usageDifference || a.id.localeCompare(b.id);
        });
      const selected = candidates[0];
      if (!selected) continue;
      data.assignments[person.id][scene] = selected.id;
      usage[selected.id] = (usage[selected.id] || 0) + 1;
      filled += 1;
    }
  }
  saveData();
  renderAll();
  showStatus(`已自动补全 ${filled} 个空缺槽位`);
}

document.querySelectorAll(".filter").forEach((button) => {
  button.addEventListener("click", () => {
    activeVoiceFilter = button.dataset.filter;
    syncFilterButtons();
    renderVoices();
  });
});
el("#autoAssign").addEventListener("click", autoAssignMissing);
el("#voiceSearch").addEventListener("input", (event) => {
  searchQuery = event.target.value;
  renderVoices();
});
el("#characterFilter").addEventListener("change", (event) => {
  characterFilter = event.target.value;
  renderCharacters();
});
el("#unbindVoice").addEventListener("click", () => {
  const person = currentPerson();
  if (!person) return;
  if (data.assignments[person.id]) delete data.assignments[person.id][activeScene];
  saveData();
  renderAll();
  showStatus(`已解除 ${person.display_name} / ${sceneLabels[activeScene]} 的绑定`);
});
document.querySelectorAll("#sceneSelector button").forEach((button) => {
  button.addEventListener("click", () => switchScene(button.dataset.scene));
});
el("#exportJson").addEventListener("click", downloadJson);
el("#copyJson").addEventListener("click", async () => {
  await navigator.clipboard.writeText(JSON.stringify(exportPayload(), null, 2));
  showStatus("JSON 已复制");
});
el("#resetAll").addEventListener("click", () => {
  if (!window.confirm("确定清空全部角色绑定、备注和喜欢标记吗？")) return;
  data = { assignments:{}, favorites:{}, notes:{} };
  saveData();
  renderAll();
  showStatus("全部选择已清空");
});

async function initialise() {
  const [peopleResponse, voicesResponse] = await Promise.all([
    fetch(PEOPLE_URL, { cache:"no-store" }),
    fetch("voice-library.json", { cache:"no-store" }),
  ]);
  if (!peopleResponse.ok) throw new Error(`${peopleResponse.status} ${peopleResponse.statusText}`);
  if (!voicesResponse.ok) throw new Error(`${voicesResponse.status} ${voicesResponse.statusText}`);
  people = await peopleResponse.json();
  voices = (await voicesResponse.json()).voices;
  activePersonId = people[0]?.id || null;
  activeVoiceFilter = currentPerson() ? suggestedCategory(currentPerson()) : "all";
  syncFilterButtons();
  renderAll();
}

initialise().catch((error) => {
  el("#selectedName").textContent = "角色资料载入失败";
  el("#selectedMeta").textContent = error.message;
});
