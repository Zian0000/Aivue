// AI Usage Menu Bar — Variables & token binding for Figma Scripter
// Run AFTER ai-usage-menu-bar-scripter.js or on your manually adjusted UI.
// If nodes are selected, only the selection is processed; otherwise the script
// scans the current page. It never rebuilds or deletes your UI.

// Anonymous scope keeps Scripter's persistent runtime from seeing duplicate
// top-level lexical declarations when this code is run or pasted repeatedly.
(async () => {
  const FONT_REGULAR = { family: "Inter", style: "Regular" };
  const FONT_BOLD = { family: "Inter", style: "Bold" };
  await Promise.all([
    figma.loadFontAsync(FONT_REGULAR),
    figma.loadFontAsync(FONT_BOLD),
  ]);

  const rgb = (hex) => {
    const v = hex.replace("#", "");
    return {
      r: parseInt(v.slice(0, 2), 16) / 255,
      g: parseInt(v.slice(2, 4), 16) / 255,
      b: parseInt(v.slice(4, 6), 16) / 255,
    };
  };
  const key = (c) => [c.r, c.g, c.b].map((n) => Math.round(n * 255)).join(",");
  const alias = (variable) => ({ type: "VARIABLE_ALIAS", id: variable.id });
  const slug = (name) => name.toLowerCase().replaceAll("/", "-").replaceAll(" ", "-");

  const existingCollections = await figma.variables.getLocalVariableCollectionsAsync();
  const existingVariables = await figma.variables.getLocalVariablesAsync();

  function collection(name) {
    return existingCollections.find((c) => c.name === name)
      || figma.variables.createVariableCollection(name);
  }

  function ensureMode(coll, name, preferDefault = false) {
    const found = coll.modes.find((m) => m.name === name);
    if (found) return found.modeId;
    if (preferDefault && coll.modes.length === 1) {
      coll.renameMode(coll.modes[0].modeId, name);
      return coll.modes[0].modeId;
    }
    return coll.addMode(name);
  }

  function variable(name, coll, type, scopes, description) {
    let v = existingVariables.find(
      (item) => item.name === name && item.variableCollectionId === coll.id
    );
    if (!v) v = figma.variables.createVariable(name, coll, type);
    v.scopes = scopes;
    v.description = description || "";
    if (typeof v.setVariableCodeSyntax === "function") {
      try {
        v.setVariableCodeSyntax("WEB", `var(--${slug(name)})`);
        v.setVariableCodeSyntax("iOS", name.replaceAll("/", "."));
      } catch (_) {}
    }
    return v;
  }

  const primitives = collection("AI Usage / Primitives");
  const semantic = collection("AI Usage / Semantic");
  const metrics = collection("AI Usage / Metrics");
  const content = collection("AI Usage / Content");
  const primitiveMode = ensureMode(primitives, "Value", true);
  // Starter/Figma plan compatibility: every collection uses one mode only.
  // The current UI is dark, so semantic variables resolve to dark primitives.
  const currentMode = ensureMode(semantic, "Current UI", true);
  const metricMode = ensureMode(metrics, "Value", true);
  const contentMode = ensureMode(content, "Default", true);

  const P = {};
  const primitiveColors = {
    "neutral/0": "FFFFFF",
    "neutral/50": "F3F4F6",
    "neutral/100": "EEF0F3",
    "neutral/200": "D7DBE1",
    "neutral/400": "A8AFBA",
    "neutral/500": "737B88",
    "neutral/650": "3A404B",
    "neutral/700": "303642",
    "neutral/800": "242831",
    "neutral/850": "1B1E24",
    "neutral/900": "16191F",
    "neutral/950": "111318",
    "blue/500": "4E9CFF",
    "blue/600": "287EE6",
    "orange/500": "FF9F43",
    "red/500": "FF5F57",
    "green/500": "45C97A",
    "purple/500": "A78BFA",
    "google/blue": "4285F4",
    "google/text": "202124",
    "google/secondary": "5F6368",
    "google/border": "DADCE0",
  };
  for (const [name, hex] of Object.entries(primitiveColors)) {
    const v = variable(name, primitives, "COLOR", [], `Primitive color #${hex}`);
    v.setValueForMode(primitiveMode, rgb(hex));
    P[name] = v;
  }

  const S = {};
  const semanticColors = {
    "color/background/canvas": "neutral/950",
    "color/background/surface": "neutral/850",
    "color/background/raised": "neutral/800",
    "color/background/hover": "neutral/700",
    "color/text/primary": "neutral/50",
    "color/text/secondary": "neutral/400",
    "color/text/tertiary": "neutral/500",
    "color/border/default": "neutral/650",
    "color/accent/primary": "blue/500",
    "color/status/warning": "orange/500",
    "color/status/danger": "red/500",
    "color/status/success": "green/500",
    "color/status/info": "purple/500",
    "color/on-accent": "neutral/0",
  };
  for (const [name, primitiveName] of Object.entries(semanticColors)) {
    const scopes = name.includes("text")
      ? ["TEXT_FILL"]
      : name === "color/on-accent"
        ? ["TEXT_FILL", "FRAME_FILL", "SHAPE_FILL"]
      : name.includes("border")
        ? ["STROKE_COLOR"]
        : ["FRAME_FILL", "SHAPE_FILL"];
    const v = variable(name, semantic, "COLOR", scopes, "Semantic color token");
    v.setValueForMode(currentMode, alias(P[primitiveName]));
    S[name] = v;
  }

  const M = {};
  function metric(name, value, scopes, description) {
    const v = variable(name, metrics, "FLOAT", scopes, description);
    v.setValueForMode(metricMode, value);
    M[name] = v;
    return v;
  }

  [0, 2, 3, 4, 5, 6, 7, 8, 10, 12, 14, 16, 18, 20, 24, 30, 32, 40, 48]
    .forEach((n) => metric(`spacing/${n}`, n, ["GAP"], `${n}px spacing`));
  [0, 3, 6, 7, 8, 9, 10, 12]
    .forEach((n) => metric(`radius/${n}`, n, ["CORNER_RADIUS"], `${n}px radius`));
  [11, 12, 13, 14, 15, 16, 24, 28, 36]
    .forEach((n) => metric(`typography/size/${n}`, n, ["FONT_SIZE"], `${n}px font size`));

  metric("size/divider", 1, ["WIDTH_HEIGHT"], "Divider thickness");
  metric("size/progress-height", 6, ["WIDTH_HEIGHT"], "Usage progress height");
  metric("size/toggle-width", 32, ["WIDTH_HEIGHT"], "Toggle width");
  metric("size/toggle-height", 18, ["WIDTH_HEIGHT"], "Toggle height");
  metric("size/menu-width", 360, ["WIDTH_HEIGHT"], "Menu popover width");
  metric("size/content-width", 328, ["WIDTH_HEIGHT"], "Menu inner width");
  metric("size/usage-width", 296, ["WIDTH_HEIGHT"], "Usage row width");
  metric("size/claude-window-width", 920, ["WIDTH_HEIGHT"], "Claude window width");
  metric("size/claude-window-height", 720, ["WIDTH_HEIGHT"], "Claude window height");
  metric("size/oauth-window-width", 720, ["WIDTH_HEIGHT"], "OAuth window width");
  metric("size/oauth-window-height", 760, ["WIDTH_HEIGHT"], "OAuth window height");
  metric("opacity/disabled", 0.42, ["OPACITY"], "Disabled control opacity");

  const T = {};
  function stringVariable(name, value, description) {
    const v = variable(name, content, "STRING", [], description);
    v.setValueForMode(contentMode, value);
    T[name] = v;
    return v;
  }

  function contentNumber(name, value, scopes, description) {
    const v = variable(name, content, "FLOAT", scopes, description);
    v.setValueForMode(contentMode, value);
    T[name] = v;
    return v;
  }

  const contentStrings = {
    "menu/dual": "C 71%   A 62%",
    "menu/codex": "C 71%",
    "menu/claude": "A 62%",
    "usage/codex/session/remaining": "剩餘 71%",
    "usage/codex/session/used": "已使用 29%",
    "usage/codex/session/reset": "18:16（4h 20m）",
    "usage/codex/weekly/remaining": "剩餘 11%",
    "usage/codex/weekly/used": "已使用 89%",
    "usage/codex/weekly/reset": "9/28 09:06（4d 19h）",
    "usage/claude/session/remaining": "剩餘 62%",
    "usage/claude/session/used": "已使用 38%",
    "usage/claude/session/reset": "15:20（1h 25m）",
    "usage/claude/weekly/remaining": "剩餘 92%",
    "usage/claude/weekly/used": "已使用 8%",
    "usage/claude/weekly/reset": "9/28 16:00（5d 2h）",
    "status/last-sync": "最後同步：13:55:12",
    "status/offline": "⚠  目前離線，已保留上次成功資料",
    "status/login-expired": "Claude 登入已失效。",
    "settings/refresh-rate": "60 秒  ⌄",
  };
  for (const [name, value] of Object.entries(contentStrings)) {
    stringVariable(name, value, "Editable sample content");
  }
  contentNumber("usage/codex/session/progress-width", 210.16, ["WIDTH_HEIGHT"], "71% of 296px");
  contentNumber("usage/codex/weekly/progress-width", 32.56, ["WIDTH_HEIGHT"], "11% of 296px");
  contentNumber("usage/claude/session/progress-width", 183.52, ["WIDTH_HEIGHT"], "62% of 296px");
  contentNumber("usage/claude/weekly/progress-width", 272.32, ["WIDTH_HEIGHT"], "92% of 296px");

  // Match the original script's dark colors to semantic variables.
  const colorBindings = new Map([
    [key(rgb("111318")), S["color/background/canvas"]],
    [key(rgb("1B1E24")), S["color/background/surface"]],
    [key(rgb("242831")), S["color/background/raised"]],
    [key(rgb("303642")), S["color/background/hover"]],
    [key(rgb("F3F4F6")), S["color/text/primary"]],
    [key(rgb("A8AFBA")), S["color/text/secondary"]],
    [key(rgb("737B88")), S["color/text/tertiary"]],
    [key(rgb("3A404B")), S["color/border/default"]],
    [key(rgb("4E9CFF")), S["color/accent/primary"]],
    [key(rgb("FF9F43")), S["color/status/warning"]],
    [key(rgb("FF5F57")), S["color/status/danger"]],
    [key(rgb("45C97A")), S["color/status/success"]],
    [key(rgb("A78BFA")), S["color/status/info"]],
    [key(rgb("FFFFFF")), S["color/on-accent"]],
    [key(rgb("4285F4")), P["google/blue"]],
    [key(rgb("202124")), P["google/text"]],
    [key(rgb("5F6368")), P["google/secondary"]],
    [key(rgb("DADCE0")), P["google/border"]],
  ]);

  const textBindings = new Map();
  for (const [name, v] of Object.entries(T)) {
    const raw = contentStrings[name];
    if (!textBindings.has(raw)) textBindings.set(raw, v);
  }

  const selectedUI = [...figma.currentPage.selection].filter(
    (n) => n.name !== "00 / Variables Guide"
  );
  const detectedUI = figma.currentPage.children.filter((n) =>
    n.name !== "00 / Variables Guide"
    && (n.name.includes("Menu Bar")
      || n.name.includes("Usage Popover")
      || n.name.includes("連結 Claude")
      || n.name.includes("Claude 登入驗證")
      || n.name.includes("Component States"))
  );
  // Prefer an explicit selection, but never let a selected Variables Guide
  // prevent the actual UI from being processed.
  const fallbackUI = figma.currentPage.children.filter(
    (n) => n.name !== "00 / Variables Guide"
  );
  const roots = selectedUI.length
    ? selectedUI
    : detectedUI.length
      ? detectedUI
      : fallbackUI;

  let colorCount = 0;
  let metricCount = 0;
  let textCount = 0;
  let paddingCount = 0;
  let customColorCount = 0;
  let customSpacingCount = 0;
  const bindingErrors = [];

  function reportBindingError(node, property, error) {
    if (bindingErrors.length >= 30) return;
    bindingErrors.push({
      node: node.name,
      nodeId: node.id,
      property,
      message: String(error && error.message ? error.message : error),
    });
  }

  function hexFromColor(color) {
    const part = (value) => Math.round(value * 255).toString(16).padStart(2, "0").toUpperCase();
    return `${part(color.r)}${part(color.g)}${part(color.b)}`;
  }

  // Preserve colors changed manually in Figma by capturing their exact value.
  function colorTokenFor(color) {
    const colorKey = key(color);
    const known = colorBindings.get(colorKey);
    if (known) return known;
    const hex = hexFromColor(color);
    const name = `custom/${hex}`;
    if (!P[name]) {
      const token = variable(name, primitives, "COLOR", [], `Captured UI color #${hex}`);
      token.setValueForMode(primitiveMode, rgb(hex));
      P[name] = token;
      customColorCount += 1;
    }
    colorBindings.set(colorKey, P[name]);
    return P[name];
  }

  // Preserve padding/gap values changed manually in Figma as spacing tokens.
  function spacingTokenFor(value) {
    if (typeof value !== "number" || !Number.isFinite(value)) return null;
    const name = `spacing/${value}`;
    if (!M[name]) {
      metric(name, value, ["GAP"], `${value}px captured UI spacing`);
      customSpacingCount += 1;
    }
    return M[name];
  }

  function bindPaints(node, property) {
    if (!(property in node) || !Array.isArray(node[property])) return;
    const updated = node[property].map((paint) => {
      if (paint.type !== "SOLID") return paint;
      const target = colorTokenFor(paint.color);
      try {
        const boundPaint = figma.variables.setBoundVariableForPaint(paint, "color", target);
        if (boundPaint.boundVariables && boundPaint.boundVariables.color) colorCount += 1;
        return boundPaint;
      } catch (error) {
        reportBindingError(node, property, error);
        return paint;
      }
    });
    try {
      node[property] = updated;
    } catch (error) {
      reportBindingError(node, property, error);
    }
  }

  function bindEffects(node) {
    if (!("effects" in node) || !Array.isArray(node.effects)) return;
    if (typeof figma.variables.setBoundVariableForEffect !== "function") return;
    const updated = node.effects.map((effect) => {
      if (!("color" in effect)) return effect;
      const target = colorTokenFor(effect.color);
      try {
        colorCount += 1;
        return figma.variables.setBoundVariableForEffect(effect, "color", target);
      } catch (error) {
        reportBindingError(node, "effects", error);
        return effect;
      }
    });
    try { node.effects = updated; } catch (error) { reportBindingError(node, "effects", error); }
  }

  function bindMetric(node, property, token, category = "metric") {
    if (!token || typeof node.setBoundVariable !== "function") return;
    try {
      node.setBoundVariable(property, token);
      if (node.boundVariables && node.boundVariables[property]) {
        metricCount += 1;
        if (category === "padding") paddingCount += 1;
      }
    } catch (error) {
      reportBindingError(node, property, error);
    }
  }

  function visit(node) {
    bindPaints(node, "fills");
    bindPaints(node, "strokes");
    bindEffects(node);

    if (node.type === "TEXT") {
      bindMetric(node, "fontSize", M[`typography/size/${Number(node.fontSize)}`]);
      const textToken = textBindings.get(node.characters);
      if (textToken) {
        try {
          node.setBoundVariable("characters", textToken);
          textCount += 1;
        } catch (error) {
          reportBindingError(node, "characters", error);
        }
      }
    }

    if ("itemSpacing" in node) {
      bindMetric(node, "itemSpacing", spacingTokenFor(node.itemSpacing));
      bindMetric(node, "paddingTop", spacingTokenFor(node.paddingTop), "padding");
      bindMetric(node, "paddingBottom", spacingTokenFor(node.paddingBottom), "padding");
      bindMetric(node, "paddingLeft", spacingTokenFor(node.paddingLeft), "padding");
      bindMetric(node, "paddingRight", spacingTokenFor(node.paddingRight), "padding");
    }

    if ("cornerRadius" in node && typeof node.cornerRadius === "number") {
      bindMetric(node, "cornerRadius", M[`radius/${node.cornerRadius}`]);
    }
    if (node.opacity === 0.42) bindMetric(node, "opacity", M["opacity/disabled"]);

    if (node.name.includes("Usage Popover")) bindMetric(node, "width", M["size/menu-width"]);
    if (node.name.startsWith("Provider / ") || node.name === "Footer Actions" || node.name === "Divider") {
      bindMetric(node, "width", M["size/content-width"]);
    }
    if (node.name.startsWith("Usage Row /") || node.name === "Header" || node.name === "Metadata") {
      bindMetric(node, "width", M["size/usage-width"]);
    }
    if (node.name.startsWith("Progress /")) {
      bindMetric(node, "width", M["size/usage-width"]);
      bindMetric(node, "height", M["size/progress-height"]);
    }
    if (node.name === "Value" && node.parent) {
      const progressTokenByParent = {
        "Progress / 71%": T["usage/codex/session/progress-width"],
        "Progress / 11%": T["usage/codex/weekly/progress-width"],
        "Progress / 62%": T["usage/claude/session/progress-width"],
        "Progress / 92%": T["usage/claude/weekly/progress-width"],
      };
      bindMetric(node, "width", progressTokenByParent[node.parent.name]);
    }
    if (node.name === "Toggle Track") {
      bindMetric(node, "width", M["size/toggle-width"]);
      bindMetric(node, "height", M["size/toggle-height"]);
    }
    if (node.name === "連結 Claude") {
      bindMetric(node, "width", M["size/claude-window-width"]);
      bindMetric(node, "height", M["size/claude-window-height"]);
    }
    if (node.name === "Claude 登入驗證") {
      bindMetric(node, "width", M["size/oauth-window-width"]);
      bindMetric(node, "height", M["size/oauth-window-height"]);
    }

    if ("children" in node) node.children.forEach(visit);
  }
  roots.forEach(visit);

  // Create one compact documentation board, without touching an existing one.
  let guide = figma.currentPage.findOne((n) => n.name === "00 / Variables Guide");
  if (!guide) {
    guide = figma.createFrame();
    guide.name = "00 / Variables Guide";
    guide.layoutMode = "VERTICAL";
    guide.primaryAxisSizingMode = "AUTO";
    guide.counterAxisSizingMode = "FIXED";
    guide.resize(760, 1);
    guide.itemSpacing = 20;
    guide.paddingTop = 32;
    guide.paddingBottom = 32;
    guide.paddingLeft = 32;
    guide.paddingRight = 32;
    guide.cornerRadius = 12;
    guide.fills = [figma.variables.setBoundVariableForPaint(
      { type: "SOLID", color: rgb("1B1E24") },
      "color",
      S["color/background/surface"]
    )];

    const makeText = (value, size, colorToken, bold = false) => {
      const t = figma.createText();
      t.fontName = bold ? FONT_BOLD : FONT_REGULAR;
      t.fontSize = size;
      t.characters = value;
      t.textAutoResize = "WIDTH_AND_HEIGHT";
      t.fills = [figma.variables.setBoundVariableForPaint(
        { type: "SOLID", color: rgb("FFFFFF") },
        "color",
        colorToken
      )];
      bindMetric(t, "fontSize", M[`typography/size/${size}`]);
      return t;
    };

    guide.appendChild(makeText("AI Usage Menu Bar / Variables", 28, S["color/text/primary"], true));
    guide.appendChild(makeText(
      "Semantic variables represent the current dark UI. Edit Content variables to preview usage values without detaching UI.",
      13,
      S["color/text/secondary"]
    ));

    const swatches = figma.createFrame();
    swatches.name = "Semantic Color Swatches";
    swatches.layoutMode = "HORIZONTAL";
    swatches.layoutWrap = "WRAP";
    swatches.primaryAxisSizingMode = "FIXED";
    swatches.counterAxisSizingMode = "AUTO";
    swatches.resize(696, 1);
    swatches.itemSpacing = 12;
    swatches.counterAxisSpacing = 12;
    for (const [name, token] of Object.entries(S)) {
      const card = figma.createFrame();
      card.name = name;
      card.layoutMode = "VERTICAL";
      card.primaryAxisSizingMode = "AUTO";
      card.counterAxisSizingMode = "FIXED";
      card.resize(160, 1);
      card.itemSpacing = 8;
      card.paddingTop = 12;
      card.paddingBottom = 12;
      card.paddingLeft = 12;
      card.paddingRight = 12;
      card.cornerRadius = 8;
      const semanticColor = token;
      card.fills = [figma.variables.setBoundVariableForPaint(
        { type: "SOLID", color: rgb("4E9CFF") },
        "color",
        semanticColor
      )];
      card.appendChild(makeText(name.replace("color/", ""), 11, S["color/text/primary"], true));
      swatches.appendChild(card);
    }
    guide.appendChild(swatches);
    guide.x = 80;
    guide.y = -520;
    figma.currentPage.appendChild(guide);
  }

  figma.currentPage.selection = roots.length ? roots : [guide];
  figma.viewport.scrollAndZoomIntoView(figma.currentPage.selection);

  return {
    collections: {
      primitives: primitives.id,
      semantic: semantic.id,
      metrics: metrics.id,
      content: content.id,
    },
    modes: { currentUI: currentMode },
    counts: {
      primitiveColors: Object.keys(P).length,
      semanticColors: Object.keys(S).length,
      metrics: Object.keys(M).length,
      contentStrings: Object.keys(T).length,
      boundColors: colorCount,
      boundMetrics: metricCount,
      boundPadding: paddingCount,
      boundText: textCount,
      capturedCustomColors: customColorCount,
      capturedCustomSpacing: customSpacingCount,
      processedRoots: roots.length,
      bindingErrors: bindingErrors.length,
    },
    errors: bindingErrors,
    guideNodeId: guide.id,
  };
})();
