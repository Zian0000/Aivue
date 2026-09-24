// AI Usage Menu Bar — compact Color + Padding variable binder
// Safe to run repeatedly in Scripter. Uses one mode per collection.
(async function () {
  var collections = await figma.variables.getLocalVariableCollectionsAsync();
  var variables = await figma.variables.getLocalVariablesAsync();
  var errors = [];
  var counts = { colors: 0, padding: 0, gaps: 0, customColors: 0, customSpacing: 0 };

  function getCollection(name, modeName) {
    var c = collections.find(function (x) { return x.name === name; });
    if (!c) {
      c = figma.variables.createVariableCollection(name);
      collections.push(c);
    }
    if (c.modes.length === 1 && c.modes[0].name !== modeName) {
      c.renameMode(c.modes[0].modeId, modeName);
    }
    return c;
  }

  var primitives = getCollection("AI Usage / Primitives", "Value");
  var semantic = getCollection("AI Usage / Semantic", "Current UI");
  var metrics = getCollection("AI Usage / Metrics", "Value");
  var primitiveMode = primitives.modes[0].modeId;
  var semanticMode = semantic.modes[0].modeId;
  var metricMode = metrics.modes[0].modeId;

  function ensureVariable(name, collection, type, scopes) {
    var v = variables.find(function (x) {
      return x.name === name && x.variableCollectionId === collection.id;
    });
    if (!v) {
      v = figma.variables.createVariable(name, collection, type);
      variables.push(v);
    }
    v.scopes = scopes;
    if (typeof v.setVariableCodeSyntax === "function") {
      try { v.setVariableCodeSyntax("WEB", "var(--" + name.replaceAll("/", "-") + ")"); } catch (_) {}
    }
    return v;
  }

  function rgb(hex) {
    return {
      r: parseInt(hex.slice(0, 2), 16) / 255,
      g: parseInt(hex.slice(2, 4), 16) / 255,
      b: parseInt(hex.slice(4, 6), 16) / 255
    };
  }

  function hex(color) {
    function p(value) { return Math.round(value * 255).toString(16).padStart(2, "0").toUpperCase(); }
    return p(color.r) + p(color.g) + p(color.b);
  }

  var semanticNames = {
    "111318": "color/background/canvas",
    "1B1E24": "color/background/surface",
    "242831": "color/background/raised",
    "303642": "color/background/hover",
    "F3F4F6": "color/text/primary",
    "A8AFBA": "color/text/secondary",
    "737B88": "color/text/tertiary",
    "3A404B": "color/border/default",
    "4E9CFF": "color/accent/primary",
    "FF9F43": "color/status/warning",
    "FF5F57": "color/status/danger",
    "45C97A": "color/status/success",
    "A78BFA": "color/status/info",
    "FFFFFF": "color/on-accent"
  };
  var colorCache = {};

  function colorVariable(color, property, node) {
    var h = hex(color);
    var cacheKey = h + ":" + property + ":" + (node.type === "TEXT" ? "text" : "shape");
    if (colorCache[cacheKey]) return colorCache[cacheKey];
    var primitiveName = "captured/" + h;
    var primitive = ensureVariable(primitiveName, primitives, "COLOR", []);
    primitive.setValueForMode(primitiveMode, rgb(h));
    var semanticName = semanticNames[h];
    if (!semanticName) {
      counts.customColors += 1;
      colorCache[cacheKey] = primitive;
      return primitive;
    }
    var scopes = property === "strokes"
      ? ["STROKE_COLOR"]
      : node.type === "TEXT"
        ? ["TEXT_FILL"]
        : ["FRAME_FILL", "SHAPE_FILL"];
    var semanticVar = ensureVariable(semanticName, semantic, "COLOR", scopes);
    semanticVar.setValueForMode(semanticMode, { type: "VARIABLE_ALIAS", id: primitive.id });
    colorCache[cacheKey] = semanticVar;
    return semanticVar;
  }

  function spacingVariable(value) {
    var name = "spacing/" + value;
    var existed = variables.some(function (x) {
      return x.name === name && x.variableCollectionId === metrics.id;
    });
    var v = ensureVariable(name, metrics, "FLOAT", ["GAP"]);
    v.setValueForMode(metricMode, value);
    if (!existed) counts.customSpacing += 1;
    return v;
  }

  function fail(node, property, error) {
    if (errors.length < 30) errors.push({ node: node.name, id: node.id, property: property, message: String(error) });
  }

  function bindPaints(node, property) {
    if (!(property in node) || !Array.isArray(node[property])) return;
    var changed = false;
    var paints = node[property].map(function (paint) {
      if (paint.type !== "SOLID") return paint;
      try {
        changed = true;
        counts.colors += 1;
        return figma.variables.setBoundVariableForPaint(paint, "color", colorVariable(paint.color, property, node));
      } catch (error) {
        fail(node, property, error);
        return paint;
      }
    });
    if (changed) {
      try { node[property] = paints; } catch (error) { fail(node, property, error); }
    }
  }

  function bindNumber(node, property, value, counter) {
    if (typeof value !== "number" || !Number.isFinite(value) || typeof node.setBoundVariable !== "function") return;
    try {
      node.setBoundVariable(property, spacingVariable(value));
      counts[counter] += 1;
    } catch (error) { fail(node, property, error); }
  }

  function visit(node) {
    bindPaints(node, "fills");
    bindPaints(node, "strokes");
    if ("itemSpacing" in node && node.layoutMode && node.layoutMode !== "NONE") {
      bindNumber(node, "itemSpacing", node.itemSpacing, "gaps");
      bindNumber(node, "paddingTop", node.paddingTop, "padding");
      bindNumber(node, "paddingBottom", node.paddingBottom, "padding");
      bindNumber(node, "paddingLeft", node.paddingLeft, "padding");
      bindNumber(node, "paddingRight", node.paddingRight, "padding");
    }
    if ("children" in node) node.children.forEach(visit);
  }

  var selected = Array.from(figma.currentPage.selection);
  var roots = selected.length ? selected : figma.currentPage.children.filter(function (n) {
    return n.name !== "00 / Variables Guide";
  });
  roots.forEach(visit);

  return {
    status: errors.length ? "completed_with_errors" : "success",
    processedRoots: roots.length,
    counts: counts,
    errorCount: errors.length,
    errors: errors
  };
})();
