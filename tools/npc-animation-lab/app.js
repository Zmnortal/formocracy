const PEOPLE_URL = "../../data/ontology/people.json";
const MAX_STYLE_FPS = 4;
const REQUIRED_ACTIONS = [
  "idle",
  "deliver",
  "happy_react",
  "happy_idle",
  "angry_react",
  "angry_idle",
  "walk_out_happy",
  "walk_out_angry",
];

const state = {
  people: [],
  person: null,
  table: null,
  tableUrl: null,
  action: null,
  frameIndex: 0,
  playing: true,
  fpsOverride: null,
  timerId: null,
  loadErrors: new Set(),
};

const elements = {
  statusLamp: document.querySelector("#statusLamp"),
  loadStatus: document.querySelector("#loadStatus"),
  characterSelect: document.querySelector("#characterSelect"),
  identityId: document.querySelector("#identityId"),
  citizenId: document.querySelector("#citizenId"),
  actionList: document.querySelector("#actionList"),
  stageTitle: document.querySelector("#stageTitle"),
  playbackBadge: document.querySelector("#playbackBadge"),
  fpsBadge: document.querySelector("#fpsBadge"),
  frameBadge: document.querySelector("#frameBadge"),
  stage: document.querySelector("#stage"),
  queueStack: document.querySelector("#queueStack"),
  actorImages: [...document.querySelectorAll(".actor-image")],
  actorImage: document.querySelector("#actorImage"),
  occlusionLayer: document.querySelector("#occlusionLayer"),
  frameFile: document.querySelector("#frameFile"),
  stageModeLabel: document.querySelector("#stageModeLabel"),
  restartButton: document.querySelector("#restartButton"),
  previousButton: document.querySelector("#previousButton"),
  playButton: document.querySelector("#playButton"),
  playSymbol: document.querySelector("#playSymbol"),
  playLabel: document.querySelector("#playLabel"),
  nextButton: document.querySelector("#nextButton"),
  timeline: document.querySelector("#timeline"),
  timelineSummary: document.querySelector("#timelineSummary"),
  fpsControl: document.querySelector("#fpsControl"),
  fpsOutput: document.querySelector("#fpsOutput"),
  resetFpsButton: document.querySelector("#resetFpsButton"),
  scaleControl: document.querySelector("#scaleControl"),
  scaleOutput: document.querySelector("#scaleOutput"),
  darknessControl: document.querySelector("#darknessControl"),
  darknessOutput: document.querySelector("#darknessOutput"),
  queueDarknessControl: document.querySelector("#queueDarknessControl"),
  queueDarknessOutput: document.querySelector("#queueDarknessOutput"),
  queueModeControl: document.querySelector("#queueModeControl"),
  occlusionControl: document.querySelector("#occlusionControl"),
  checkerControl: document.querySelector("#checkerControl"),
  contractStatus: document.querySelector("#contractStatus"),
  uniqueFrameCount: document.querySelector("#uniqueFrameCount"),
  errorCount: document.querySelector("#errorCount"),
  fatalOverlay: document.querySelector("#fatalOverlay"),
  fatalMessage: document.querySelector("#fatalMessage"),
};

function resourceToUrl(path, baseUrl = window.location.href) {
  if (path.startsWith("res://")) {
    return new URL(`../../${path.slice("res://".length)}`, window.location.href).href;
  }
  return new URL(path, baseUrl).href;
}

function basename(path) {
  return decodeURIComponent(path.split("/").at(-1) || path);
}

function setLoadState(kind, message) {
  elements.statusLamp.className = `status-lamp ${kind}`;
  elements.loadStatus.textContent = message;
}

function showFatal(error) {
  setLoadState("error", "动画档案载入失败");
  elements.fatalMessage.textContent =
    window.location.protocol === "file:"
      ? "浏览器禁止 file:// 页面读取项目 JSON。"
      : `读取项目数据失败：${error.message}`;
  elements.fatalOverlay.hidden = false;
}

function currentFps() {
  if (!state.action) return 1;
  return Math.min(MAX_STYLE_FPS, state.fpsOverride ?? Number(state.action.fps) ?? 1);
}

function currentFramePath(index = state.frameIndex) {
  if (!state.action?.frames?.length) return "";
  if (state.table?.substitute_frames_with_static_actor && state.person?.actor_texture) {
    return state.person.actor_texture;
  }
  return state.action.frames[index] || state.action.frames[0];
}

function currentFrameUrl(index = state.frameIndex) {
  return resourceToUrl(currentFramePath(index), state.tableUrl);
}

function stopTimer() {
  if (state.timerId !== null) {
    window.clearTimeout(state.timerId);
    state.timerId = null;
  }
}

function scheduleNextFrame() {
  stopTimer();
  if (!state.playing || !state.action?.frames?.length) return;
  state.timerId = window.setTimeout(advanceFrame, 1000 / currentFps());
}

function advanceFrame() {
  if (!state.action) return;
  const lastIndex = state.action.frames.length - 1;
  if (state.frameIndex < lastIndex) {
    state.frameIndex += 1;
  } else if (state.action.playback === "LOOP") {
    state.frameIndex = 0;
  } else {
    state.playing = false;
  }
  renderFrame();
  renderPlaybackButton();
  scheduleNextFrame();
}

function setPlaying(playing) {
  state.playing = playing;
  renderPlaybackButton();
  scheduleNextFrame();
}

function restartAction() {
  state.frameIndex = 0;
  setPlaying(true);
  renderFrame();
}

function stepFrame(delta) {
  if (!state.action) return;
  const frameCount = state.action.frames.length;
  state.frameIndex = (state.frameIndex + delta + frameCount) % frameCount;
  setPlaying(false);
  renderFrame();
}

function renderPlaybackButton() {
  elements.playSymbol.textContent = state.playing ? "Ⅱ" : "▶";
  elements.playLabel.textContent = state.playing ? "暂停" : "播放";
}

function markImageError(url) {
  state.loadErrors.add(url);
  elements.errorCount.textContent = String(state.loadErrors.size);
  elements.errorCount.classList.add("warn");
  const matchingFrame = [...elements.timeline.querySelectorAll(".frame-button")].find(
    (button) => button.dataset.url === url,
  );
  matchingFrame?.classList.add("error");
  setLoadState("error", `发现 ${state.loadErrors.size} 个资源错误`);
}

function renderFrame() {
  if (!state.action?.frames?.length) return;
  const url = currentFrameUrl();
  for (const image of elements.actorImages) {
    if (image.src !== url) {
      image.src = url;
    }
  }
  elements.actorImage.alt = `${state.person.display_name} / ${state.action.action} / 第 ${state.frameIndex + 1} 帧`;
  elements.frameFile.textContent = basename(currentFramePath());
  elements.frameBadge.textContent = `${state.frameIndex + 1} / ${state.action.frames.length}`;
  elements.fpsBadge.textContent = `${currentFps()} FPS`;
  elements.fpsOutput.textContent = `${currentFps()} FPS`;
  elements.fpsControl.value = String(currentFps());
  [...elements.timeline.children].forEach((button, index) => {
    button.classList.toggle("active", index === state.frameIndex);
  });
}

function renderTimeline() {
  elements.timeline.replaceChildren();
  if (!state.action) return;
  state.action.frames.forEach((framePath, index) => {
    const url = resourceToUrl(framePath, state.tableUrl);
    const button = document.createElement("button");
    button.className = "frame-button";
    button.type = "button";
    button.dataset.url = url;
    button.title = basename(framePath);
    button.setAttribute("aria-label", `跳到第 ${index + 1} 帧：${basename(framePath)}`);

    const image = document.createElement("img");
    image.src =
      state.table?.substitute_frames_with_static_actor && state.person?.actor_texture
        ? resourceToUrl(state.person.actor_texture)
        : url;
    image.alt = "";
    image.loading = "eager";
    image.addEventListener("error", () => markImageError(url), { once: true });

    const number = document.createElement("span");
    number.className = "frame-number";
    number.textContent = String(index + 1).padStart(2, "0");

    button.append(image, number);
    button.addEventListener("click", () => {
      state.frameIndex = index;
      setPlaying(false);
      renderFrame();
    });
    elements.timeline.append(button);
  });
  elements.timelineSummary.textContent = `${state.action.frames.length} 张 · ${state.action.playback}`;
}

function renderActionList() {
  elements.actionList.replaceChildren();
  for (const action of state.table.actions) {
    const button = document.createElement("button");
    button.className = "action-button";
    button.classList.toggle("active", action.action === state.action?.action);
    button.type = "button";
    button.innerHTML = `
      <span>${action.action}</span>
      <small>${action.frames.length} 帧 · ${action.fps} FPS</small>
      <span class="action-mode">${action.playback}</span>
    `;
    button.addEventListener("click", () => selectAction(action.action));
    elements.actionList.append(button);
  }
}

function renderDiagnostics() {
  const actionNames = new Set(state.table.actions.map((action) => action.action));
  const missing = REQUIRED_ACTIONS.filter((action) => !actionNames.has(action));
  const configuredRequired = state.table.action_contract?.required || [];
  const contractMatches =
    missing.length === 0 && REQUIRED_ACTIONS.every((action) => configuredRequired.includes(action));
  elements.contractStatus.textContent = contractMatches ? "符合" : `缺少 ${missing.length}`;
  elements.contractStatus.classList.toggle("warn", !contractMatches);

  const uniqueFrames = new Set(state.table.actions.flatMap((action) => action.frames));
  const maxFrames = state.table.action_contract?.max_unique_pngs ?? "—";
  elements.uniqueFrameCount.textContent = `${uniqueFrames.size} / ${maxFrames}`;
  elements.uniqueFrameCount.classList.toggle(
    "warn",
    typeof maxFrames === "number" && uniqueFrames.size > maxFrames,
  );
}

function selectAction(actionName) {
  const nextAction = state.table.actions.find((action) => action.action === actionName);
  if (!nextAction) return;
  state.action = nextAction;
  state.frameIndex = 0;
  state.fpsOverride = null;
  state.playing = true;
  elements.stageTitle.textContent = `${state.person.display_name} / ${nextAction.action}`;
  elements.playbackBadge.textContent = nextAction.playback;
  renderActionList();
  renderTimeline();
  renderPlaybackButton();
  renderFrame();
  scheduleNextFrame();
}

function renderCharacterIdentity() {
  elements.identityId.textContent = state.person.id;
  elements.citizenId.textContent = state.person.citizen_id || "—";
}

async function loadCharacter(personId) {
  stopTimer();
  setLoadState("", "正在读取角色动画表");
  state.person = state.people.find((person) => person.id === personId) || state.people[0];
  state.tableUrl = resourceToUrl(state.person.animation_table);
  const response = await fetch(state.tableUrl, { cache: "no-store" });
  if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
  state.table = await response.json();
  state.loadErrors.clear();
  elements.errorCount.textContent = "0";
  elements.errorCount.classList.remove("warn");
  renderCharacterIdentity();
  renderDiagnostics();
  const initialAction =
    state.table.actions.find((action) => action.action === state.table.default_animation) ||
    state.table.actions[0];
  selectAction(initialAction.action);
  setLoadState("ready", `${state.person.display_name} 动画表已载入`);
}

function populateCharacters() {
  elements.characterSelect.replaceChildren();
  for (const person of state.people) {
    const option = document.createElement("option");
    const isProduction = !person.animation_table.includes("default_applicant");
    option.value = person.id;
    option.textContent = `${person.queue_label || "—"} · ${person.display_name} · ${
      isProduction ? "正式逐帧" : "默认兼容"
    }`;
    elements.characterSelect.append(option);
  }
}

function applyVisualControls() {
  const scale = Number(elements.scaleControl.value) / 100;
  const darkness = 1 - Number(elements.darknessControl.value) / 100;
  const queueDarkness = Number(elements.queueDarknessControl.value) / 100;

  document.documentElement.style.setProperty("--actor-scale", String(scale));
  document.documentElement.style.setProperty("--actor-darkness", String(darkness));
  elements.scaleOutput.textContent = `${elements.scaleControl.value}%`;
  elements.darknessOutput.textContent = `${elements.darknessControl.value}%`;
  elements.queueDarknessOutput.textContent = `${elements.queueDarknessControl.value}%`;

  const queueImages = elements.actorImages;
  queueImages[0].style.filter = `brightness(${Math.max(0.05, 1 - queueDarkness - 0.15)})`;
  queueImages[1].style.filter = `brightness(${Math.max(0.05, 1 - queueDarkness)})`;
  queueImages[2].style.filter = `brightness(${darkness})`;
}

function applyStageModes() {
  elements.queueStack.classList.toggle("queue-mode", elements.queueModeControl.checked);
  elements.occlusionLayer.classList.toggle("hidden", !elements.occlusionControl.checked);
  elements.stage.classList.toggle("checkerboard", elements.checkerControl.checked);
  elements.stageModeLabel.textContent = elements.queueModeControl.checked ? "排队检查" : "单人检查";
}

function bindControls() {
  elements.characterSelect.addEventListener("change", async (event) => {
    try {
      await loadCharacter(event.target.value);
    } catch (error) {
      showFatal(error);
    }
  });
  elements.restartButton.addEventListener("click", restartAction);
  elements.previousButton.addEventListener("click", () => stepFrame(-1));
  elements.nextButton.addEventListener("click", () => stepFrame(1));
  elements.playButton.addEventListener("click", () => setPlaying(!state.playing));
  elements.fpsControl.addEventListener("input", () => {
    state.fpsOverride = Number(elements.fpsControl.value);
    elements.fpsOutput.textContent = `${currentFps()} FPS`;
    elements.fpsBadge.textContent = `${currentFps()} FPS`;
    scheduleNextFrame();
  });
  elements.resetFpsButton.addEventListener("click", () => {
    state.fpsOverride = null;
    renderFrame();
    scheduleNextFrame();
  });
  for (const input of [
    elements.scaleControl,
    elements.darknessControl,
    elements.queueDarknessControl,
  ]) {
    input.addEventListener("input", applyVisualControls);
  }
  for (const input of [
    elements.queueModeControl,
    elements.occlusionControl,
    elements.checkerControl,
  ]) {
    input.addEventListener("change", applyStageModes);
  }
  for (const image of elements.actorImages) {
    image.addEventListener("error", () => markImageError(image.src));
  }
  window.addEventListener("keydown", (event) => {
    const target = event.target;
    if (target instanceof HTMLInputElement || target instanceof HTMLSelectElement) return;
    if (event.code === "Space") {
      event.preventDefault();
      setPlaying(!state.playing);
    } else if (event.key === "ArrowLeft") {
      stepFrame(-1);
    } else if (event.key === "ArrowRight") {
      stepFrame(1);
    } else if (event.key.toLowerCase() === "r") {
      restartAction();
    } else if (/^[1-4]$/.test(event.key)) {
      state.fpsOverride = Number(event.key);
      renderFrame();
      scheduleNextFrame();
    }
  });
  document.addEventListener("visibilitychange", () => {
    if (document.hidden) {
      stopTimer();
    } else {
      scheduleNextFrame();
    }
  });
}

async function initialise() {
  bindControls();
  applyVisualControls();
  applyStageModes();
  if (window.location.protocol === "file:") {
    showFatal(new Error("file protocol"));
    return;
  }
  try {
    const response = await fetch(PEOPLE_URL, { cache: "no-store" });
    if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
    state.people = await response.json();
    populateCharacters();
    const preferredPerson = state.people.find((person) => person.id === "PROPRIETOR-HE") || state.people[0];
    elements.characterSelect.value = preferredPerson.id;
    await loadCharacter(preferredPerson.id);
  } catch (error) {
    showFatal(error);
  }
}

initialise();
