(() => {
  const page = document.body.dataset.page;
  document.querySelectorAll("[data-nav]").forEach((link) => {
    if (link.dataset.nav === page) {
      link.setAttribute("aria-current", "page");
    }
  });

  const decisionData = {
    redeem: {
      code: "V-01 / PROCEDURALLY VALID",
      title: "正常兑付主管保障券",
      copy:
        "所有材料均有效。玩家按手册完成兑付，高层申请人取得最后一个医疗验收位；杜春梅的申请被系统顺延。",
      values: ["程序风险：低", "公共伤害：高", "监察关注：低"],
    },
    refuse: {
      code: "V-01 / UNSUPPORTED REFUSAL",
      title: "直接拒绝兑付",
      copy:
        "玩家保留了杜春梅的医疗资源，但日报会记录一次没有现行条款依据的拒绝。决定能否持续，取决于此前保存的证据。",
      values: ["程序风险：极高", "公共伤害：低", "人物信任：上升"],
    },
    delay: {
      code: "V-01 / MANUAL REVIEW",
      title: "转入人工复核",
      copy:
        "玩家利用签发人权限与资源分类问题拖延兑付。它不是无代价的聪明答案：两名申请人都可能错过当天资源。",
      values: ["程序风险：中", "公共伤害：不确定", "证据要求：中"],
    },
    reclassify: {
      code: "V-01 / EMERGENCY RECLASSIFICATION",
      title: "把杜春梅重新归入紧急资源",
      copy:
        "只有污染紧急条款、医院急件和验收机异常证据能够共同支撑这一决定。玩家因此公开连接了多宗本应独立的案件。",
      values: ["程序风险：高", "公共伤害：最低", "证据要求：极高"],
    },
  };

  const decisionPanel = document.querySelector("[data-decision-panel]");
  if (decisionPanel) {
    const code = decisionPanel.querySelector("[data-decision-code]");
    const title = decisionPanel.querySelector("[data-decision-title]");
    const copy = decisionPanel.querySelector("[data-decision-copy]");
    const values = [...decisionPanel.querySelectorAll("[data-decision-value]")];
    document.querySelectorAll("[data-decision]").forEach((button) => {
      button.addEventListener("click", () => {
        const data = decisionData[button.dataset.decision];
        if (!data) return;
        document.querySelectorAll("[data-decision]").forEach((item) => {
          item.setAttribute(
            "aria-selected",
            item === button ? "true" : "false",
          );
        });
        code.textContent = data.code;
        title.textContent = data.title;
        copy.textContent = data.copy;
        values.forEach((value, index) => {
          value.textContent = data.values[index] || "";
        });
      });
    });
  }

  const checklistKey = "formocracy-special-case-template-checklist";
  const checklist = [...document.querySelectorAll("[data-check-item]")];
  if (checklist.length) {
    const stored = JSON.parse(localStorage.getItem(checklistKey) || "{}");
    checklist.forEach((input) => {
      input.checked = Boolean(stored[input.dataset.checkItem]);
      input.addEventListener("change", () => {
        const next = {};
        checklist.forEach((item) => {
          next[item.dataset.checkItem] = item.checked;
        });
        localStorage.setItem(checklistKey, JSON.stringify(next));
      });
    });
  }
})();
