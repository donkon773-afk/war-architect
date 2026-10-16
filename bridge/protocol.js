"use strict";

const ACTIONS = new Set([
  "ADVANCE", "ASSAULT", "HOLD", "RETREAT", "RECON", "REQUEST_FIRE",
  "BOARD", "DISEMBARK", "REPAIR", "SET_ROE", "SET_SECTOR", "REPORT", "CANCEL",
  "REQUEST_SUPPORT", "SHARE_INTEL", "NEGOTIATE", "DESIGNATE", "AUTONOMY", "BUY", "ASSIGN_ROLE", "AIR_TASK"
]);
const POSITION_ACTIONS = new Set(["ADVANCE", "ASSAULT", "RETREAT", "REQUEST_FIRE", "SET_SECTOR", "DESIGNATE", "AIR_TASK"]);
const ROE = new Set(["HOLD_FIRE", "RETURN_FIRE", "OPEN_FIRE"]);
const SUPPORT = new Set(["ARTILLERY", "MORTAR", "CAS"]);
/* 4.5.0: BUY spends the group's own Warlords CP on vanilla requisition; the
 * kind travels in the same "support" slot so the strict schema stays flat. */
const PURCHASE_KINDS = new Set(["INFANTRY", "CAR", "APC", "TANK", "TRUCK", "HELICOPTER", "PLANE", "UAV"]);
const ROLES=new Set(["INFANTRY","MECHANIZED","ARMOR","RECON","AIR_TRANSPORT","AIR_CAS","AIR_SUPERIORITY"]);
const AIR_TASKS=new Set(["CAS","RECON","TRANSPORT","INTERCEPT","ESCORT"]);
const DANGEROUS = /\b(?:compile|execvm|preprocessfile|remoteexec|spawn|call|eval|systemchat|deletevehicle)\b|<script|[;{}]/i;

function cleanText(value, maxLength) {
  if (typeof value !== "string") return "";
  return value
    .replace(/[\u0000-\u001f\u007f]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, maxLength);
}

function isSafeText(value) {
  return typeof value === "string" && !DANGEROUS.test(value);
}

function parseJsonObject(raw) {
  if (typeof raw !== "string") return null;
  let text = raw.replace(/<think>[\s\S]*?(?:<\/think>|$)/gi, "").trim();
  const fenced = text.match(/^```(?:json)?\s*([\s\S]*?)\s*```$/i);
  if (fenced) text = fenced[1].trim();
  try {
    return JSON.parse(text);
  } catch (_) {
    const first = text.indexOf("{");
    const last = text.lastIndexOf("}");
    if (first < 0 || last <= first) return null;
    try {
      return JSON.parse(text.slice(first, last + 1));
    } catch (_) {
      return null;
    }
  }
}

function validatePosition(value) {
  if (!Array.isArray(value) || value.length < 2) return null;
  const x = Number(value[0]);
  const y = Number(value[1]);
  if (!Number.isFinite(x) || !Number.isFinite(y) || x < 0 || y < 0 || x > 100000 || y > 100000) return null;
  return [Math.round(x), Math.round(y)];
}

const TEMPLATES = { ASSAULT: ["CQB", "RUSH"], HOLD: ["GARRISON", "DEFEND"], RECON: ["HUNT", "CREEP"] };
function validateAction(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const type = String(value.type || "").toUpperCase().trim();
  if (!ACTIONS.has(type)) return null;

  const position = validatePosition(value.position || value.target_position || value.pos);
  if (POSITION_ACTIONS.has(type) && !position) return null;

  let argument = "";
  if (type === "SET_ROE") {
    argument = String(value.roe || value.argument || "").toUpperCase().trim();
    if (!ROE.has(argument)) return null;
  }
  if (type === "REQUEST_FIRE") {
    argument = String(value.support || value.argument || "ARTILLERY").toUpperCase().trim();
    if (!SUPPORT.has(argument)) return null;
  }
  if (type === "BUY") {
    argument = String(value.support || value.argument || "TANK").toUpperCase().trim();
    if (!PURCHASE_KINDS.has(argument)) return null;
  }
  /* 8.10 behaviour templates (LAMBS tasks): an unknown template degrades to the plain order. */
  if (TEMPLATES[type]) {
    const t = String(value.support || value.argument || "").toUpperCase().trim();
    argument = TEMPLATES[type].includes(t) ? t : "";
  }
  if(type==="ASSIGN_ROLE"){argument=String(value.support||value.argument||"").toUpperCase().trim();if(!ROLES.has(argument))return null;}
  if(type==="AIR_TASK"){argument=String(value.support||value.argument||"").toUpperCase().trim();if(!AIR_TASKS.has(argument))return null;}
  return [type, position || [], argument];
}

function fallbackResponse(message = "Не могу подтвердить тактическое решение. Повторите приказ.") {
  return { ok: false, speech: cleanText(message, 420) || "Повторите приказ.", actions: [] };
}

function extractOrderText(snapshot) {
  try {
    const parsed = parseSqfValue(String(snapshot || ""));
    if (!Array.isArray(parsed)) return "";
    const index = parsed.indexOf("order");
    return index >= 0 && typeof parsed[index + 1] === "string" ? parsed[index + 1] : "";
  } catch (_) {
    return "";
  }
}

function normalizeNaturalText(value) {
  return cleanText(value, 420)
    .toLowerCase()
    .replace(/ё/g, "е")
    .replace(/[‐‑‒–—―−]/g, "-");
}

/* Three-digit Arma grids are 100 m cells: 057 090 -> [5700, 9000].
 * Comma/semicolon/colon pairs remain literal world coordinates for backwards
 * compatibility with existing 4-5 digit orders and bridge tests. */
function parseOrderPosition(order) {
  const text = normalizeNaturalText(order);
  const match = text.match(/\[?\s*(\d{2,5})(\s+|\s*[,;:]\s*)(\d{2,5})\s*\]?/u);
  if (!match) return null;
  const gridNotation = /^\s+$/.test(match[2]) && match[1].length === match[3].length && match[1].length <= 3;
  if (!gridNotation) return validatePosition([match[1], match[3]]);
  /* A two-digit pair is also accepted as an omitted leading zero in the
   * common three-digit radio grid used by the current Takistan scenario. */
  const scale = 100;
  return validatePosition([Number(match[1]) * scale, Number(match[3]) * scale]);
}

function snapshotField(parsed, name, fallback = []) {
  if (!Array.isArray(parsed)) return fallback;
  const index = parsed.indexOf(name);
  return index >= 0 && index + 1 < parsed.length ? parsed[index + 1] : fallback;
}

function classWords(value) {
  return normalizeNaturalText(value).replace(/[^a-zа-я0-9]+/giu, " ").trim();
}

function chooseNearest(rows, origin, predicate = () => true) {
  const candidates = [];
  for (const row of Array.isArray(rows) ? rows : []) {
    if (!Array.isArray(row) || !predicate(row)) continue;
    const position = validatePosition(Array.isArray(row[2]) ? row[2] : row[1]);
    if (!position) continue;
    const distance = origin ? Math.hypot(position[0] - origin[0], position[1] - origin[1]) : 0;
    candidates.push([distance, position]);
  }
  candidates.sort((left, right) => left[0] - right[0]);
  return candidates.length ? candidates[0][1] : null;
}

function inferIntentPositions(intents, snapshot) {
  if (!Array.isArray(intents) || intents.length === 0) return intents || [];
  let parsed;
  try { parsed = parseSqfValue(String(snapshot || "")); } catch (_) { return intents; }
  const order = normalizeNaturalText(extractOrderText(snapshot));
  const groups = snapshotField(parsed, "groups", []);
  const player = validatePosition(snapshotField(parsed, "player", [])) || validatePosition(snapshotField(parsed, "observer", []));
  const groupOrigin = validatePosition(Array.isArray(groups) && Array.isArray(groups[0]) ? groups[0][2] : null) || player;
  const assets = snapshotField(parsed, "assets", []);
  const locations = snapshotField(parsed, "locations", []);
  const sharedIntel = snapshotField(parsed, "sharedIntel", []);
  /* 4.4.0: Warlords sectors [name,[x,y],owner,distM,isBase] are the natural
   * targets of "attack/take/move to the sector|point|objective". */
  const sideKey = String(snapshotField(parsed, "side", "") || "");
  const sectors = (snapshotField(parsed, "sectors", []) || []).filter(row => Array.isArray(row) && validatePosition(row[1]));
  const sectorRows = sectors.map(row => [String(row[0] || ""), row[1], String(row[2] || ""), row[4] === true]);
  const namedSector = chooseNearest(sectorRows, groupOrigin, row => {
    const name = normalizeNaturalText(row[0]);
    return name.length >= 3 && order.includes(name);
  });
  const objectiveSector = chooseNearest(sectorRows, groupOrigin, row => !row[3] && row[2] !== sideKey);
  const groupIntel = [];
  for (const group of Array.isArray(groups) ? groups : []) {
    if (Array.isArray(group) && Array.isArray(group[5])) groupIntel.push(...group[5]);
  }

  const namedLocation = chooseNearest(locations, groupOrigin, row => {
    const name = normalizeNaturalText(row[0]);
    return name.length >= 3 && order.includes(name);
  });
  const basePosition = chooseNearest([...groupIntel, ...sharedIntel], player || groupOrigin, row => /modulewlbase/i.test(String(row[0] || "")));
  const sectorPosition = chooseNearest([...groupIntel, ...sharedIntel], groupOrigin, row => /modulewlsector/i.test(String(row[0] || "")));
  const enemyPosition = chooseNearest([...groupIntel, ...sharedIntel], groupOrigin, row => !/^(?:logic|module)/i.test(String(row[0] || "")));
  const assetPosition = chooseNearest(assets, groupOrigin, row => {
    const className = classWords(row[0]);
    const category = normalizeNaturalText(row[1]);
    if (/брэдл|бредл|bradley/.test(order)) return /bradley/.test(className);
    if (/[мm]1+126/.test(order)) return /m1126/.test(className);
    if (/\bбтр\b/.test(order)) return category === "apc" || /btr|lav|m1126|stryker/.test(className);
    if (/\bбмп\b/.test(order)) return /bmp|bradley|warrior|marder/.test(className) || category === "apc";
    if (/танк/.test(order)) return category === "tank" || /m1a|t72|t80|t90|leopard|abrams/.test(className);
    return /техник|брон|машин|транспорт/.test(order) && ["apc", "tank", "car"].includes(category);
  });

  return intents.map(intent => {
    if (!intent || intent.position) return intent;
    let position = null;
    if (intent.type === "BOARD") position = assetPosition || (order.includes("баз") ? basePosition : null);
    else if (namedSector) position = namedSector;
    else if (namedLocation) position = namedLocation;
    else if (order.includes("баз") && basePosition) position = basePosition;
    else if (["ASSAULT", "ADVANCE"].includes(intent.type) && /цел|точк|сектор|задач|объект/.test(order)) position = objectiveSector || sectorPosition;
    else if (["ASSAULT", "SET_SECTOR", "DESIGNATE", "REQUEST_FIRE"].includes(intent.type)) position = enemyPosition || (intent.type === "ASSAULT" ? objectiveSector : null);
    if (position) return { ...intent, position };
    /* No position from the text: leave the intent open so bindSingleExplicitOrder
     * can adopt the model's own grounded plan for it (it used to be downgraded to
     * RECON here, BEFORE the model's answer was even looked at). */
    return intent;
  });
}

function classifyPlayerMessage(snapshot) {
  const order = normalizeNaturalText(extractOrderText(snapshot));
  const question = /\?|(?:^|\s)(?:куда|где|когда|почему|зачем|сколько|каков|какая|какие|что происходит|что видите|как обстановка|как дела|как там|как настрой|доложите|доложи|статус|обстановка)(?=\s|$|[.,!?])/u.test(order);
  const imperative = /атак(?:уй|уйте|овать)|штурм(?:уй|уйте|овать)|зачист(?:и|ите)|выдвиг(?:айся|айтесь|аться)|двиг(?:айся|айтесь)|\bидите\b|следуйте|занять|займ(?:и|ите)|садитесь|сесть|найд(?:и|ите)|отыщ(?:и|ите)|удерживайте|обороняйте|отходите|отступайте|разведайте|наблюдайте|осмотрите|доложите|передайте|запросите|подсветите|ремонтируйте|почините|высадитесь|спешьтесь|отмените|прекратите|действуйте|решайте|проявите/u.test(order);
  const information = /(?:^|\s)(?:взлетает|вылетел|появился|появилась|обнаружен|обнаружена|вижу|сообщаю|замечен|замечена|подходит|на подходе|прибыл|прибывает)(?=\s|$|[.,!?])/u.test(order);
  /* Pure role-play radio chatter: greetings, praise, morale, acknowledgement.
   * Handled as talk-only so the group answers in character without touching its task. */
  const chatter = /(?:^|\s)(?:привет|здаров|здравств|добро пожаловать|молодц|молодчин|отличн[оа]|хорошая работа|так держать|благодар|спасибо|как сам|бойцы|парни|братья|держитесь|не подведите|удачи|с богом|конец связи|прием|принял|вас понял|отбой|работайте|красавц)/u.test(order);
  if (question) return { kind: "QUESTION", order };
  if (information && !imperative) return { kind: "INFORMATION", order };
  if (chatter && !imperative) return { kind: "CHATTER", order };
  return { kind: "ORDER", order };
}

function validateModelResponse(raw, limits = {}) {
  const maxSpeech = Number(limits.maxSpeechChars) || 420;
  const maxActions = Math.min(Math.max(Number(limits.maxActions) || 3, 1), 6);
  const data = parseJsonObject(raw);
  if (!data || typeof data !== "object" || Array.isArray(data) || Number(data.version) !== 3) {
    return fallbackResponse();
  }
  let speech = cleanText(data.speech, maxSpeech);
  if (!speech || !isSafeText(speech)) speech = "Вас понял. Исполняю безопасный манёвр.";
  const actions = [];
  /* Inspect a bounded input window first: rejected items must not consume the action budget. */
  const rawActions = Array.isArray(data.actions) ? data.actions.slice(0, 16) : [];
  for (const action of rawActions) {
    const valid = validateAction(action);
    if (!valid || actions.length >= maxActions) continue;
    /* gpt-5-mini sometimes repeats the same action twice in one plan; the SQF
     * side would just no-op the duplicate, so drop it here. */
    const previous = actions[actions.length - 1];
    if (previous && JSON.stringify(previous) === JSON.stringify(valid)) continue;
    actions.push(valid);
  }
  return { ok: true, speech, actions };
}

/*
 * An explicit player imperative must not be silently exchanged for another
 * model-chosen action.  This parser intentionally recognises a small tactical
 * vocabulary only.  Ambiguous movement/fire commands still require a grounded
 * coordinate from the player's text or from the model's validated proposal.
 */
function explicitOrderIntent(snapshot) {
  const source = String(snapshot || "");
  const marker = '"order",';
  const markerIndex = source.indexOf(marker);
  if (markerIndex < 0) return null;
  const tail = source.slice(markerIndex + marker.length).trimStart();
  if (!tail.startsWith('"')) return null;
  let text = "";
  let closed = false;
  for (let index = 1; index < tail.length; index++) {
    if (tail[index] !== '"') { text += tail[index]; continue; }
    if (tail[index + 1] === '"') { text += '"'; index++; continue; }
    closed = true;
    break;
  }
  if (!closed) return null;
  const order = normalizeNaturalText(text.replace(/\\"/g, '"'));
  const position = parseOrderPosition(order);
  const distanceMatch = order.match(/(?:на\s+|дистанци[а-я]*\s+)(\d{1,4})\s*(?:м(?:етр[а-я]*)?)(?=\s|$|[.,!?])/);
  const distance = distanceMatch ? Math.min(Math.max(Number(distanceMatch[1]), 10), 2000) : 300;
  let relative = null;
  const azimuth = order.match(/(?:азимут\w*|курс\w*)\s*(\d{1,3})/);
  if (azimuth) relative = { mode: "DIR", bearing: Number(azimuth[1]) % 360, distance };
  if (!relative) {
    const cardinals = [
      [/северо[-\s]?восток\w*/, 45], [/юго[-\s]?восток\w*/, 135],
      [/юго[-\s]?запад\w*/, 225], [/северо[-\s]?запад\w*/, 315],
      [/север\w*/, 0], [/восток\w*/, 90], [/юг\w*/, 180], [/запад\w*/, 270]
    ];
    const cardinal = cardinals.find(([pattern]) => pattern.test(order));
    if (cardinal) relative = { mode: "DIR", bearing: cardinal[1], distance };
  }
  if (!relative) {
    const localDirections = [
      [/(?:вперед|прямо)(?=\s|$|[.,!?])/, 0], [/(?:вправо|справа)(?=\s|$|[.,!?])/, 90],
      [/(?:назад|обратно)(?=\s|$|[.,!?])/, 180], [/(?:влево|слева)(?=\s|$|[.,!?])/, 270]
    ];
    const localDirection = localDirections.find(([pattern]) => pattern.test(order));
    if (localDirection) relative = { mode: "REL", bearing: localDirection[1], distance };
  }
  const spatial = type => ({ type, position, ...(relative ? { relative } : {}) });
  const vehicleWord = /танк\w*|техник\w*|бтр|бмп|брон\w*|машин\w*|транспорт\w*|вертолет\w*|самолет\w*|[мm]\d{3,5}|\bicv\b/.test(order);

  if (/самостоятель|по обстановк|на свое усмотрен|проявите инициатив|решайте сами/.test(order)) return { type: "AUTONOMY" };
  if (/разберитесь|реагируйте по обстановк|прикройте союз|подстрахуйте союз/.test(order)) return { type: "AUTONOMY" };
  if (vehicleWord && /за[нй]|сесть|посад|экипаж|войти|найд|отыщ/.test(order)) return position ? { type: "BOARD", position } : { type: "BOARD" };
  if (/высад\w*|спеш\w*|покин\w*.*техник/.test(order)) return { type: "DISEMBARK" };
  /* 4.5.0: "купите / закажите / запросите по реквизиции танк|бтр|бмп|машину|
   * грузовик|людей" — spend the group's own CP on vanilla Warlords requisition. */
  if (/куп\w*|закаж\w*|заказ\w*|реквиз\w*|приобрет\w*/.test(order)) {
    const kind = /танк\w*/.test(order) ? "TANK"
      : (/бтр|бмп|брон\w*|apc/.test(order) ? "APC"
      : (/грузовик\w*|транспорт\w*|урал|камаз/.test(order) ? "TRUCK"
      : (/люд\w*|бойц\w*|пехот\w*|солдат\w*|пополнен\w*|стрелк\w*|пулемет\w*|гранатомет\w*/.test(order) ? "INFANTRY"
      : (/машин\w*|джип\w*|уаз|хамв\w*|пикап\w*|техник\w*/.test(order) ? "CAR" : "TANK"))));
    return { type: "BUY", argument: kind };
  }
  if (/ремонт\w*|почин\w*|восстанов\w*/.test(order)) return { type: "REPAIR" };
  if (/подсвет\w*|целеуказ\w*|лазер\w*/.test(order)) return spatial("DESIGNATE");
  if (/артиллер\w*|миномет\w*|авиац\w*.*поддерж|cas\b/.test(order)) {
    const support = /миномет\w*/.test(order) ? "MORTAR" : (/авиац\w*|cas\b/.test(order) ? "CAS" : "ARTILLERY");
    return { ...spatial("REQUEST_FIRE"), argument: support };
  }
  if (/подмог\w*|поддержк\w*|резерв\w*|усилен\w*/.test(order)) return { type: "REQUEST_SUPPORT", position };
  if (/переговор\w*|координир\w*|свяж\w*|согласу\w*/.test(order)) return { type: "NEGOTIATE", position };
  if (/переда\w*.*развед|разведдан|переда\w*.*контакт|сообщ\w*.*контакт/.test(order)) return { type: "SHARE_INTEL" };
  if (/долож\w*|отчет\w*|обстановк\w*|статус\w*/.test(order)) return { type: "REPORT" };
  if (/отмен\w*|прекрат\w*|стоп/.test(order)) return { type: "CANCEL" };
  if (/не\s*стрел|не\s*откры|огонь\s*не\s*откры|не\s*вступа\w*\s+в\s+бой|в\s+бой\s+не\s+вступа\w*|избега\w*\s+бо[яй]/.test(order)) return { type: "SET_ROE", argument: "HOLD_FIRE" };
  if (/ответн\w*\s+огонь|огонь\s+по\s+готовност/.test(order)) return { type: "SET_ROE", argument: "RETURN_FIRE" };
  if (/откры\w*\s+огонь|свободн\w*\s+огонь|огонь\s+на\s+поражен/.test(order)) return { type: "SET_ROE", argument: "OPEN_FIRE" };
  /* 4.4.0: "сектор" is first of all a Warlords OBJECTIVE. An attack or move
   * verb next to it is an assault/advance on that sector, not a watch sector;
   * only an observation phrasing (or a bare "сектор") still means SET_SECTOR. */
  if (/штурм\w*|атак\w*|зачист\w*/.test(order) && /сектор\w*|точк\w*|цел\w*|объект\w*/.test(order)) return spatial("ASSAULT");
  if (/выдвиг\w*|двига\w*|движ\w*|ид(?:и|ем|ти|ите)|следу\w*|занять\s+позиц|займ\w*/.test(order) && /сектор\w*|точк\w*|цел\w*|объект\w*/.test(order)) return spatial("ADVANCE");
  if (/сектор\w*|наблюд\w*.*(?:север|юг|запад|восток|направлен)|смотр\w*\s+в/.test(order)) return spatial("SET_SECTOR");
  if (/развед\w*|наблюда\w*|осмотр\w*/.test(order)) return { type: "RECON" };
  if (/штурм\w*|атак\w*|зачист\w*/.test(order)) return spatial("ASSAULT");
  if (/отход\w*|отступ\w*|покин\w*\s+позиц/.test(order)) return spatial("RETREAT");
  if (/удерж\w*|оборона|закреп\w*|стоять/.test(order)) return { type: "HOLD" };
  if (/выдвиг\w*|двига\w*|движ\w*|ид(?:и|ем|ти|ите)|следу\w*|занять\s+позиц/.test(order)) return spatial("ADVANCE");
  return null;
}

function explicitOrderIntents(snapshot) {
  const source = String(snapshot || "");
  const marker = '"order",';
  const markerIndex = source.indexOf(marker);
  if (markerIndex < 0) return [];
  const tail = source.slice(markerIndex + marker.length).trimStart();
  if (!tail.startsWith('"')) return [];
  let text = "";
  for (let index = 1; index < tail.length; index++) {
    if (tail[index] !== '"') { text += tail[index]; continue; }
    if (tail[index + 1] === '"') { text += '"'; index++; continue; }
    break;
  }
  const clauses = text
    .split(/\s+(?:и\s+затем|затем|после\s+этого|и)\s+|[;.!?]+|(?<!\d),(?!\d)/iu)
    .map(value => value.trim())
    .filter(Boolean);
  const intents = [];
  for (const clause of clauses) {
    const intent = explicitOrderIntent(toSqfValue(["v", 3, "order", clause]));
    if (intent) intents.push(intent);
    if (intents.length >= 3) break;
  }
  if (intents.length === 0) {
    const whole = explicitOrderIntent(snapshot);
    if (whole) intents.push(whole);
  }
  return intents;
}

function isGroundedPosition(position, snapshot) {
  const candidate = validatePosition(position);
  if (!candidate || typeof snapshot !== "string" || snapshot.length === 0) return false;
  let parsed;
  try { parsed = parseSqfValue(snapshot); } catch (_) { return false; }
  const known = [];
  const visit = value => {
    if (!Array.isArray(value)) return;
    if (value.length >= 2 && Number.isFinite(Number(value[0])) && Number.isFinite(Number(value[1]))) {
      const normalized = validatePosition([value[0], value[1]]);
      if (normalized && (normalized[0] > 0 || normalized[1] > 0)) known.push(normalized);
    }
    for (const nested of value) visit(nested);
  };
  visit(parsed);
  return known.some(([x, y]) => Math.hypot(candidate[0] - x, candidate[1] - y) <= 350);
}

const AUTONOMOUS_MOVE_ACTIONS = new Set(["ADVANCE", "ASSAULT", "RETREAT"]);

/*
 * An autonomous plan must not order a group to march onto the patch of ground it
 * already occupies.  Such a "self-move" passes isGroundedPosition trivially (zero
 * metres from the group's own reported coordinate) and, reissued every planning
 * cycle, freezes the group in place while fatigue climbs.  Non-move spatial
 * actions (SET_SECTOR / DESIGNATE / REQUEST_FIRE) may legitimately reference the
 * group's own position, so they are not constrained here.
 */
function groupOriginFromSnapshot(snapshot) {
  let parsed;
  try { parsed = parseSqfValue(String(snapshot || "")); } catch (_) { return null; }
  const groups = snapshotField(parsed, "groups", []);
  const first = Array.isArray(groups) && Array.isArray(groups[0]) ? groups[0][2] : null;
  return validatePosition(first)
    || validatePosition(snapshotField(parsed, "observer", []))
    || validatePosition(snapshotField(parsed, "player", []));
}

function autonomousMoveIsMeaningful(type, position, snapshot, minMeters = 35) {
  if (!AUTONOMOUS_MOVE_ACTIONS.has(String(type || "").toUpperCase().trim())) return true;
  const target = validatePosition(position);
  if (!target) return false;
  const origin = groupOriginFromSnapshot(snapshot);
  if (!origin) return true;
  const threshold = Number.isFinite(Number(minMeters)) ? Math.max(Number(minMeters), 0) : 35;
  return Math.hypot(target[0] - origin[0], target[1] - origin[1]) >= threshold;
}

function bindSingleExplicitOrder(actions, intent, snapshot) {
  if (!intent) return { actions, unresolved: false };
  const type = intent.type;
  const positionAction = POSITION_ACTIONS.has(type);
  let position = intent.position || null;
  if (positionAction && !position) {
    const matching = Array.isArray(actions) ? actions.find(action =>
      Array.isArray(action) &&
      action[0] === type &&
      validatePosition(action[1]) &&
      (typeof snapshot !== "string" || isGroundedPosition(action[1], snapshot))
    ) : null;
    position = matching ? matching[1] : null;
  }
  if (positionAction && !position && intent.relative && ["DIR", "REL"].includes(intent.relative.mode)) {
    const bearing = Math.round(Number(intent.relative.bearing));
    const distance = Math.round(Number(intent.relative.distance));
    if (Number.isFinite(bearing) && Number.isFinite(distance)) {
      return { actions: [[type, [], `${intent.relative.mode}:${bearing}:${distance}`]], unresolved: false };
    }
  }
  if (positionAction && !position) {
    /* Last resort: any grounded manoeuvre the model itself produced. */
    const anyMove = Array.isArray(actions) ? actions.find(action =>
      Array.isArray(action) && ["ADVANCE", "ASSAULT"].includes(action[0]) && validatePosition(action[1]) &&
      (typeof snapshot !== "string" || isGroundedPosition(action[1], snapshot))) : null;
    if (anyMove) return { actions: [[type === "ASSAULT" || type === "ADVANCE" ? type : anyMove[0], anyMove[1], intent.argument || ""]], unresolved: false };
    /* A vague attack with nothing to attack becomes reconnaissance, not silence. */
    if (type === "ASSAULT") return { actions: [["RECON", [], ""]], unresolved: false };
    return { actions: [], unresolved: true };
  }
  return { actions: [[type, position || [], intent.argument || ""]], unresolved: false };
}

function bindExplicitOrder(actions, intentOrIntents, snapshot) {
  if (!Array.isArray(intentOrIntents)) return bindSingleExplicitOrder(actions, intentOrIntents, snapshot);
  if (intentOrIntents.length === 0) return { actions, unresolved: false };
  const bound = [];
  let unresolved = false;
  for (const intent of intentOrIntents.slice(0, 3)) {
    const result = bindSingleExplicitOrder(actions, intent, snapshot);
    unresolved ||= result.unresolved;
    for (const action of result.actions) {
      if (bound.length < 3) bound.push(action);
    }
  }
  return { actions: bound, unresolved };
}

function toSqfValue(value) {
  if (Array.isArray(value)) return `[${value.map(toSqfValue).join(",")}]`;
  if (typeof value === "string") {
    return `"${value.replace(/[\u0000-\u001f\u007f]/g, " ").replace(/"/g, '""')}"`;
  }
  if (typeof value === "number" && Number.isFinite(value)) return String(Math.round(value * 1000) / 1000);
  if (typeof value === "boolean") return value ? "true" : "false";
  throw new TypeError("Only arrays, strings, finite numbers and booleans are valid NeroAI SQF transport values");
}

function parseSqfValue(text) {
  let index = 0;
  const skip = () => { while (/\s/.test(text[index] || "")) index++; };
  const parse = () => {
    skip();
    const current = text[index];
    if (current === "[") {
      index++;
      const result = [];
      skip();
      if (text[index] === "]") { index++; return result; }
      while (true) {
        result.push(parse());
        skip();
        if (text[index] === "]") { index++; return result; }
        if (text[index] !== ",") throw new SyntaxError("Expected comma in SQF array");
        index++;
      }
    }
    if (current === '"') {
      index++;
      let result = "";
      while (index < text.length) {
        if (text[index] === '"') {
          if (text[index + 1] === '"') { result += '"'; index += 2; continue; }
          index++;
          return result;
        }
        result += text[index++];
      }
      throw new SyntaxError("Unterminated SQF string");
    }
    const match = text.slice(index).match(/^(true|false|-?\d+(?:\.\d+)?)/i);
    if (!match) throw new SyntaxError("Unsupported SQF transport value");
    index += match[0].length;
    if (/^true$/i.test(match[0])) return true;
    if (/^false$/i.test(match[0])) return false;
    return Number(match[0]);
  };
  const result = parse();
  skip();
  if (index !== text.length) throw new SyntaxError("Unexpected suffix in SQF transport value");
  return result;
}

/*
 * INIDBI2 can persist an SQF array in two forms: an outer wrapper around an
 * otherwise valid SQF value, or a wrapper which doubles every inner quote.
 * Both must be accepted without corrupting the JSON string inside a snapshot.
 */
function parseIniTransportValue(rawValue) {
  const raw = String(rawValue || "").trim();
  if (!raw) throw new SyntaxError("Empty INIDBI2 transport value");

  const candidates = [raw];
  if (raw.length >= 2 && raw.startsWith('"') && raw.endsWith('"')) {
    const unwrapped = raw.slice(1, -1).trim();
    candidates.push(unwrapped);
    const deEscaped = unwrapped.replace(/""/g, '"');
    if (deEscaped !== unwrapped) candidates.push(deEscaped);
  }

  let scalarResult;
  let lastError;
  for (const candidate of candidates) {
    try {
      const parsed = parseSqfValue(candidate);
      if (Array.isArray(parsed)) return parsed;
      if (typeof parsed === "string") {
        try {
          const nested = parseSqfValue(parsed);
          if (Array.isArray(nested)) return nested;
        } catch (error) {
          lastError = error;
        }
        if (scalarResult === undefined) scalarResult = parsed;
        continue;
      }
      return parsed;
    } catch (error) {
      lastError = error;
    }
  }
  if (scalarResult !== undefined) return scalarResult;
  throw lastError || new SyntaxError("Unsupported INIDBI2 transport value");
}

function parseIniEntries(contents, sectionName, onParseError = () => {}) {
  const result = new Map();
  let inSection = false;
  for (const rawLine of String(contents || "").split(/\r?\n/)) {
    const line = rawLine.trim().replace(/^\uFEFF/, "");
    if (!line || line.startsWith(";") || line.startsWith("#")) continue;
    const section = line.match(/^\[([^\]]+)\]$/);
    if (section) { inSection = section[1] === sectionName; continue; }
    if (!inSection) continue;
    const assignment = rawLine.match(/^\s*([^=\s]+)\s*=\s*(.+?)\s*$/);
    if (!assignment) continue;
    try {
      result.set(assignment[1], parseIniTransportValue(assignment[2]));
    } catch (error) {
      /* A partial atomic-looking line may become valid on the next poll. */
      try { onParseError(assignment[1], error); } catch (_) { /* diagnostics must never break polling */ }
    }
  }
  return result;
}

module.exports = {
  ACTIONS,
  cleanText,
  parseJsonObject,
  validateModelResponse,
  explicitOrderIntent,
  explicitOrderIntents,
  extractOrderText,
  parseOrderPosition,
  inferIntentPositions,
  classifyPlayerMessage,
  bindExplicitOrder,
  isGroundedPosition,
  groupOriginFromSnapshot,
  autonomousMoveIsMeaningful,
  toSqfValue,
  parseSqfValue,
  parseIniTransportValue,
  parseIniEntries,
  fallbackResponse
};
