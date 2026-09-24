// AI Usage Menu Bar — Figma Scripter
// Paste the whole file into Scripter and run it on an editable Figma page.

async function main() {
  const regular = { family: "Inter", style: "Regular" };
  const bold = { family: "Inter", style: "Bold" };
  await Promise.all([figma.loadFontAsync(regular), figma.loadFontAsync(bold)]);

  const C = {
    canvas: rgb("111318"),
    surface: rgb("1B1E24"),
    raised: rgb("242831"),
    hover: rgb("303642"),
    line: rgb("3A404B"),
    label: rgb("F3F4F6"),
    secondary: rgb("A8AFBA"),
    tertiary: rgb("737B88"),
    blue: rgb("4E9CFF"),
    orange: rgb("FF9F43"),
    red: rgb("FF5F57"),
    green: rgb("45C97A"),
    purple: rgb("A78BFA"),
    white: rgb("FFFFFF"),
  };

  function rgb(hex) {
    const value = hex.replace("#", "");
    return {
      r: parseInt(value.slice(0, 2), 16) / 255,
      g: parseInt(value.slice(2, 4), 16) / 255,
      b: parseInt(value.slice(4, 6), 16) / 255,
    };
  }

  function fill(color, opacity = 1) {
    return [{ type: "SOLID", color, opacity }];
  }

  function stack(name, direction = "VERTICAL", gap = 0, padding = 0) {
    const node = figma.createFrame();
    node.name = name;
    node.layoutMode = direction;
    node.itemSpacing = gap;
    node.paddingTop = padding;
    node.paddingBottom = padding;
    node.paddingLeft = padding;
    node.paddingRight = padding;
    node.primaryAxisSizingMode = "AUTO";
    node.counterAxisSizingMode = "AUTO";
    node.fills = [];
    node.clipsContent = false;
    return node;
  }

  function fixed(node, width, height) {
    node.resize(width, height);
    node.primaryAxisSizingMode = "FIXED";
    node.counterAxisSizingMode = "FIXED";
    return node;
  }

  function text(value, size = 13, color = C.label, weight = "Regular") {
    const node = figma.createText();
    node.fontName = weight === "Bold" ? bold : regular;
    node.fontSize = size;
    node.characters = value;
    node.fills = fill(color);
    node.textAutoResize = "WIDTH_AND_HEIGHT";
    return node;
  }

  function divider(width = 328) {
    const node = figma.createRectangle();
    node.name = "Divider";
    node.resize(width, 1);
    node.fills = fill(C.line);
    return node;
  }

  function badge(label, color) {
    const node = stack(`Badge / ${label}`, "HORIZONTAL", 4, 5);
    node.cornerRadius = 6;
    node.fills = fill(color, 0.16);
    node.appendChild(text(label, 11, color, "Bold"));
    return node;
  }

  function button(label, kind = "secondary", width) {
    const node = stack(`Button / ${label}`, "HORIZONTAL", 6, 8);
    node.cornerRadius = 7;
    node.primaryAxisAlignItems = "CENTER";
    node.counterAxisAlignItems = "CENTER";
    node.fills = fill(kind === "primary" ? C.blue : kind === "danger" ? C.red : C.raised);
    const labelNode = text(label, 12, kind === "primary" || kind === "danger" ? C.white : C.label, "Bold");
    node.appendChild(labelNode);
    if (width) {
      node.resize(width, 32);
      node.primaryAxisSizingMode = "FIXED";
    }
    return node;
  }

  function iconButton(glyph) {
    const node = stack(`Icon Button / ${glyph}`, "HORIZONTAL", 0, 7);
    node.cornerRadius = 7;
    node.fills = fill(C.raised);
    node.appendChild(text(glyph, 13, C.label, "Bold"));
    return node;
  }

  function progress(value, color, width = 296) {
    const track = figma.createFrame();
    track.name = "Toggle Track";
    track.name = `Progress / ${value}%`;
    track.resize(width, 6);
    track.fills = fill(C.hover);
    track.cornerRadius = 3;
    track.clipsContent = true;
    const bar = figma.createRectangle();
    bar.name = "Value";
    bar.resize(Math.max(6, width * value / 100), 6);
    bar.fills = fill(color);
    bar.cornerRadius = 3;
    track.appendChild(bar);
    return track;
  }

  function usageRow(title, remaining, used, reset, tone = "blue") {
    const color = tone === "red" ? C.red : tone === "orange" ? C.orange : C.blue;
    const box = stack(`Usage Row / ${title}`, "VERTICAL", 7, 0);
    box.resize(296, 65);
    box.counterAxisSizingMode = "FIXED";

    const top = stack("Header", "HORIZONTAL", 8, 0);
    top.resize(296, 20);
    top.primaryAxisSizingMode = "FIXED";
    top.primaryAxisAlignItems = "SPACE_BETWEEN";
    top.appendChild(text(title, 13, C.label, "Bold"));
    top.appendChild(text(`剩餘 ${remaining}%`, 14, C.label, "Bold"));
    box.appendChild(top);
    box.appendChild(progress(remaining, color));

    const bottom = stack("Metadata", "HORIZONTAL", 8, 0);
    bottom.resize(296, 18);
    bottom.primaryAxisSizingMode = "FIXED";
    bottom.primaryAxisAlignItems = "SPACE_BETWEEN";
    bottom.appendChild(text(`已使用 ${used}%`, 11, C.secondary));
    bottom.appendChild(text(reset, 11, C.secondary));
    box.appendChild(bottom);
    return box;
  }

  function provider(name, mark, plan, first, second, options = {}) {
    const box = stack(`Provider / ${name}`, "VERTICAL", 12, 0);
    // Keep height on HUG. Provider states contain different numbers of rows;
    // a fixed height makes Disconnect and Settings overlap in Figma.
    box.resize(328, 1);
    box.counterAxisSizingMode = "FIXED";
    box.primaryAxisSizingMode = "AUTO";

    const head = stack("Provider Header", "HORIZONTAL", 8, 0);
    head.resize(328, 24);
    head.primaryAxisSizingMode = "FIXED";
    head.counterAxisAlignItems = "CENTER";
    const logo = badge(mark, name === "Claude" ? C.orange : C.blue);
    head.appendChild(logo);
    head.appendChild(text(name, 14, C.label, "Bold"));
    head.appendChild(badge(plan, C.secondary));
    const spacer = figma.createFrame();
    spacer.name = "Flexible Space";
    spacer.resize(1, 1);
    spacer.layoutGrow = 1;
    spacer.fills = [];
    head.appendChild(spacer);
    if (options.loading) head.appendChild(text("◌", 16, C.blue, "Bold"));
    box.appendChild(head);
    box.appendChild(usageRow(first.title, first.remaining, first.used, first.reset, first.tone));
    box.appendChild(usageRow(second.title, second.remaining, second.used, second.reset, second.tone));
    box.appendChild(text("最後同步：13:55:12", 11, C.secondary));

    if (options.stale) {
      const stale = stack("Stale Warning", "HORIZONTAL", 6, 0);
      stale.appendChild(text("◷", 12, C.orange, "Bold"));
      stale.appendChild(text("資料已過期", 11, C.orange));
      box.appendChild(stale);
    }
    if (options.message) {
      const warning = stack("Error Message", "HORIZONTAL", 6, 0);
      warning.resize(328, 30);
      warning.primaryAxisSizingMode = "FIXED";
      warning.counterAxisSizingMode = "AUTO";
      warning.primaryAxisAlignItems = "SPACE_BETWEEN";
      warning.counterAxisAlignItems = "CENTER";
      warning.appendChild(text("⚠", 12, C.orange));
      const message = text(options.message, 11, C.orange);
      message.resize(options.connect ? 220 : 296, 18);
      message.textAutoResize = "HEIGHT";
      warning.appendChild(message);
      if (options.connect) warning.appendChild(button("連結"));
      box.appendChild(warning);
    }
    if (options.disconnect) box.appendChild(text("斷開連結", 11, C.red));
    return box;
  }

  function toggle(label, enabled = true, disabled = false) {
    const row = stack(`Toggle / ${label}`, "HORIZONTAL", 8, 0);
    row.resize(296, 24);
    row.primaryAxisSizingMode = "FIXED";
    row.primaryAxisAlignItems = "SPACE_BETWEEN";
    row.counterAxisAlignItems = "CENTER";
    row.opacity = disabled ? 0.42 : 1;
    row.appendChild(text(label, 12, C.label));
    const track = figma.createFrame();
    track.resize(32, 18);
    track.cornerRadius = 9;
    track.fills = fill(enabled ? C.green : C.hover);
    const knob = figma.createEllipse();
    knob.resize(14, 14);
    knob.x = enabled ? 16 : 2;
    knob.y = 2;
    knob.fills = fill(C.white);
    track.appendChild(knob);
    row.appendChild(track);
    return row;
  }

  function settings(expanded = false) {
    const box = stack(`Settings / ${expanded ? "Expanded" : "Collapsed"}`, "VERTICAL", 8, 0);
    box.resize(328, expanded ? 126 : 22);
    box.counterAxisSizingMode = "FIXED";
    const title = stack("Disclosure Header", "HORIZONTAL", 7, 0);
    title.appendChild(text(expanded ? "▾" : "▸", 11, C.secondary));
    title.appendChild(text("顯示與更新", 12, C.label, "Bold"));
    box.appendChild(title);
    if (expanded) {
      box.appendChild(toggle("Codex", true));
      box.appendChild(toggle("Claude", true));
      const picker = stack("Picker / Sync Frequency", "HORIZONTAL", 8, 0);
      picker.resize(296, 28);
      picker.primaryAxisSizingMode = "FIXED";
      picker.primaryAxisAlignItems = "SPACE_BETWEEN";
      picker.appendChild(text("同步頻率", 12, C.label));
      const value = badge("60 秒  ⌄", C.secondary);
      picker.appendChild(value);
      box.appendChild(picker);
    }
    return box;
  }

  function footer() {
    const row = stack("Footer Actions", "HORIZONTAL", 8, 0);
    row.resize(328, 32);
    row.primaryAxisSizingMode = "FIXED";
    row.counterAxisAlignItems = "CENTER";
    row.appendChild(button("↻  全部更新"));
    row.appendChild(iconButton("⎘"));
    const spacer = figma.createFrame();
    spacer.resize(1, 1);
    spacer.layoutGrow = 1;
    spacer.fills = [];
    row.appendChild(spacer);
    row.appendChild(button("結束"));
    return row;
  }

  function popover(name, opts = {}) {
    const panel = stack(name, "VERTICAL", 14, 16);
    // Width is fixed to match the SwiftUI menu, height hugs all state rows.
    panel.resize(360, 1);
    panel.primaryAxisSizingMode = "AUTO";
    panel.counterAxisSizingMode = "FIXED";
    panel.fills = fill(C.surface);
    panel.cornerRadius = 12;
    panel.strokes = fill(C.line);
    panel.strokeWeight = 1;
    panel.effects = [{ type: "DROP_SHADOW", color: { ...C.canvas, a: 0.55 }, offset: { x: 0, y: 12 }, radius: 30, spread: 0, visible: true, blendMode: "NORMAL" }];

    panel.appendChild(provider("Codex", "C", "PLUS",
      { title: "5 小時區段", remaining: 71, used: 29, reset: "18:16（4h 20m）", tone: "blue" },
      { title: "7 天總額度", remaining: 11, used: 89, reset: "9/28 09:06（4d 19h）", tone: "red" },
      opts.stale ? { stale: true } : {}
    ));
    panel.appendChild(divider());
    panel.appendChild(provider("Claude", "A", "PRO",
      { title: "目前區段", remaining: 62, used: 38, reset: "15:20（1h 25m）", tone: "blue" },
      { title: "本週總額度", remaining: 92, used: 8, reset: "9/28 16:00（5d 2h）", tone: "blue" },
      opts.claudeError ? { message: "Claude 登入已失效。", connect: true } : { disconnect: true }
    ));
    panel.appendChild(divider());
    panel.appendChild(settings(Boolean(opts.expanded)));
    if (opts.offline) {
      const offline = stack("Offline Banner", "HORIZONTAL", 6, 8);
      offline.cornerRadius = 7;
      offline.fills = fill(C.orange, 0.12);
      offline.appendChild(text("⚠  目前離線，已保留上次成功資料", 11, C.orange));
      panel.appendChild(offline);
    }
    panel.appendChild(divider());
    panel.appendChild(footer());
    return panel;
  }

  function statusPill(label, state = "normal") {
    const pill = stack(`Menu Bar / ${label}`, "HORIZONTAL", 7, 7);
    pill.cornerRadius = 7;
    pill.fills = fill(C.raised);
    pill.appendChild(text(state === "offline" ? "⊘" : "✦", 12, state === "offline" ? C.orange : C.label, "Bold"));
    pill.appendChild(text(label, 12, C.label, "Bold"));
    return pill;
  }

  function macWindow(name, width, height, contentBuilder) {
    const window = stack(name, "VERTICAL", 0, 0);
    fixed(window, width, height);
    window.fills = fill(C.surface);
    window.cornerRadius = 12;
    window.strokes = fill(C.line);
    window.strokeWeight = 1;
    window.clipsContent = true;

    const chrome = stack("macOS Title Bar", "HORIZONTAL", 8, 12);
    chrome.resize(width, 48);
    chrome.primaryAxisSizingMode = "FIXED";
    chrome.counterAxisSizingMode = "FIXED";
    chrome.counterAxisAlignItems = "CENTER";
    for (const color of [C.red, rgb("FFBD2E"), C.green]) {
      const dot = figma.createEllipse();
      dot.resize(12, 12);
      dot.fills = fill(color);
      chrome.appendChild(dot);
    }
    chrome.appendChild(text(name, 13, C.secondary, "Bold"));
    window.appendChild(chrome);
    contentBuilder(window, width, height - 48);
    return window;
  }

  function claudeWindow() {
    return macWindow("連結 Claude", 920, 720, (window, width, bodyHeight) => {
      const toolbar = stack("Connection Toolbar", "HORIZONTAL", 12, 12);
      toolbar.resize(width, 72);
      toolbar.primaryAxisSizingMode = "FIXED";
      toolbar.counterAxisSizingMode = "FIXED";
      toolbar.counterAxisAlignItems = "CENTER";
      const labels = stack("Title", "VERTICAL", 3, 0);
      labels.appendChild(text("連結 Claude", 15, C.label, "Bold"));
      labels.appendChild(text("登入資料只會送往 claude.ai", 11, C.secondary));
      toolbar.appendChild(labels);
      const spacer = figma.createFrame(); spacer.resize(1, 1); spacer.layoutGrow = 1; spacer.fills = [];
      toolbar.appendChild(spacer);
      toolbar.appendChild(badge("✓ 已連結", C.green));
      toolbar.appendChild(iconButton("↻"));
      window.appendChild(toolbar);
      window.appendChild(divider(width));

      const web = figma.createFrame();
      web.name = "WKWebView / Claude.ai";
      web.resize(width, bodyHeight - 121);
      web.fills = fill(C.canvas);
      const webContent = stack("Claude Page Placeholder", "VERTICAL", 18, 0);
      webContent.x = 48; webContent.y = 44;
      webContent.appendChild(text("Claude", 28, C.label, "Bold"));
      webContent.appendChild(text("官方 claude.ai 內嵌頁面", 14, C.secondary));
      webContent.appendChild(button("使用 Google 繼續", "secondary", 280));
      web.appendChild(webContent);
      window.appendChild(web);
      window.appendChild(divider(width));

      const bottom = stack("Connected Footer", "HORIZONTAL", 12, 12);
      bottom.resize(width, 48);
      bottom.primaryAxisSizingMode = "FIXED";
      bottom.counterAxisSizingMode = "FIXED";
      bottom.primaryAxisAlignItems = "SPACE_BETWEEN";
      bottom.counterAxisAlignItems = "CENTER";
      bottom.appendChild(text("連結完成後可關閉此視窗。", 11, C.secondary));
      bottom.appendChild(button("讀取用量", "primary"));
      window.appendChild(bottom);
    });
  }

  function oauthWindow() {
    return macWindow("Claude 登入驗證", 720, 760, (window, width, bodyHeight) => {
      const page = stack("Google OAuth", "VERTICAL", 20, 40);
      page.resize(width, bodyHeight);
      page.primaryAxisSizingMode = "FIXED";
      page.counterAxisSizingMode = "FIXED";
      page.counterAxisAlignItems = "CENTER";
      page.fills = fill(C.white);
      page.appendChild(text("G", 36, rgb("4285F4"), "Bold"));
      page.appendChild(text("登入 Google", 24, rgb("202124"), "Bold"));
      page.appendChild(text("繼續前往 Claude", 14, rgb("5F6368")));
      const account = stack("Account Row", "HORIZONTAL", 12, 16);
      account.resize(420, 64); account.primaryAxisSizingMode = "FIXED";
      account.cornerRadius = 8; account.strokes = fill(rgb("DADCE0")); account.strokeWeight = 1;
      account.appendChild(badge("Z", rgb("5F6368")));
      account.appendChild(text("Zian  ·  zian@example.com", 13, rgb("202124")));
      page.appendChild(account);
      page.appendChild(button("繼續", "primary", 180));
      window.appendChild(page);
    });
  }

  function stateCard(title, tone, description) {
    const card = stack(`State / ${title}`, "VERTICAL", 10, 14);
    card.resize(300, 112);
    card.primaryAxisSizingMode = "FIXED";
    card.counterAxisSizingMode = "FIXED";
    card.cornerRadius = 10;
    card.fills = fill(C.surface);
    card.strokes = fill(C.line);
    card.strokeWeight = 1;
    card.appendChild(badge(title, tone));
    const body = text(description, 12, C.secondary);
    body.resize(272, 42);
    body.textAutoResize = "HEIGHT";
    card.appendChild(body);
    return card;
  }

  const pageTitle = text("AI Usage Menu Bar · UI Inventory", 28, C.label, "Bold");
  pageTitle.x = 80;
  pageTitle.y = 60;
  figma.currentPage.appendChild(pageTitle);

  const statusGroup = stack("01 / Menu Bar States", "HORIZONTAL", 12, 16);
  statusGroup.x = 80; statusGroup.y = 120;
  statusGroup.fills = fill(C.surface);
  statusGroup.cornerRadius = 12;
  statusGroup.appendChild(statusPill("C 71%   A 62%"));
  statusGroup.appendChild(statusPill("C 71%"));
  statusGroup.appendChild(statusPill("A 62%"));
  statusGroup.appendChild(statusPill("C 71%   A 62%", "offline"));
  figma.currentPage.appendChild(statusGroup);

  const mainPanel = popover("02 / Usage Popover / Default");
  mainPanel.x = 80; mainPanel.y = 220;
  figma.currentPage.appendChild(mainPanel);

  const expandedPanel = popover("03 / Usage Popover / Settings + Offline", { expanded: true, offline: true, stale: true });
  expandedPanel.x = 480; expandedPanel.y = 220;
  figma.currentPage.appendChild(expandedPanel);

  const errorPanel = popover("04 / Usage Popover / Login Expired", { claudeError: true });
  errorPanel.x = 880; errorPanel.y = 220;
  figma.currentPage.appendChild(errorPanel);

  const login = claudeWindow();
  login.x = 80; login.y = 1020;
  figma.currentPage.appendChild(login);

  const oauth = oauthWindow();
  oauth.x = 1040; oauth.y = 1020;
  figma.currentPage.appendChild(oauth);

  const states = stack("07 / Component States", "HORIZONTAL", 16, 0);
  states.x = 80; states.y = 1820;
  states.appendChild(stateCard("載入中", C.blue, "正在讀取用量…\n使用旋轉進度指示。"));
  states.appendChild(stateCard("資料過期", C.orange, "保留上次成功百分比，附加過期標記。"));
  states.appendChild(stateCard("低用量", C.red, "剩餘低於 20%，進度條與數字改為紅色。"));
  states.appendChild(stateCard("離線", C.orange, "顯示 Wi-Fi 斷線狀態，仍保留快取。"));
  states.appendChild(stateCard("需要登入", C.orange, "顯示錯誤原因與「連結」按鈕。"));
  figma.currentPage.appendChild(states);

  const nodes = [statusGroup, mainPanel, expandedPanel, errorPanel, login, oauth, states];
  figma.currentPage.selection = nodes;
  figma.viewport.scrollAndZoomIntoView(nodes);
  figma.notify("已建立 AI Usage Menu Bar UI 畫板");
}

await main();
