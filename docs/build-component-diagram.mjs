#!/usr/bin/env node
// Generates component-diagram.excalidraw with embedded SVG icons
// Re-run: node docs/build-component-diagram.mjs
// Render: excalirender docs/component-diagram.excalidraw -o docs/component-diagram.png -s 2
import { readFileSync, writeFileSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const iconsDir = join(__dirname, "icons");

function loadIcon(filename) {
  const svg = readFileSync(join(iconsDir, filename));
  const b64 = svg.toString("base64");
  return `data:image/svg+xml;base64,${b64}`;
}

// Load all icons
const icons = {
  packer: { id: "file_packer", dataURL: loadIcon("packer.svg") },
  ami: { id: "file_ami", dataURL: loadIcon("aws-ami.svg") },
  ec2: { id: "file_ec2", dataURL: loadIcon("aws-ec2.svg") },
  paramStore: { id: "file_paramstore", dataURL: loadIcon("aws-parameter-store.svg") },
  secretsMgr: { id: "file_secretsmgr", dataURL: loadIcon("aws-secrets-manager.svg") },
  confd: { id: "file_confd", dataURL: loadIcon("confd-gear.svg") },
  teleport: { id: "file_teleport", dataURL: loadIcon("teleport.svg") },
  datadog: { id: "file_datadog", dataURL: loadIcon("datadog.svg") },
};

// Build files map
const files = {};
for (const [, icon] of Object.entries(icons)) {
  files[icon.id] = {
    mimeType: "image/svg+xml",
    id: icon.id,
    dataURL: icon.dataURL,
    created: Date.now(),
  };
}

const ICON = 64;
const ICON_SM = 48;
const elements = [];

// ─── Helpers ───────────────────────────────────────────────────────────

function addImage(id, fileId, x, y, size) {
  elements.push({
    type: "image", id, x, y, width: size, height: size,
    fileId, status: "saved",
  });
}

function addText(id, x, y, text, opts = {}) {
  const fontSize = opts.fontSize ?? 16;
  elements.push({
    type: "text", id, x, y,
    width: opts.width ?? text.length * fontSize * 0.6,
    height: opts.height ?? fontSize + 8,
    text, fontSize, fontFamily: 1,
    strokeColor: opts.color ?? "#1e1e1e",
    textAlign: opts.align ?? "center",
    verticalAlign: opts.vAlign ?? "top",
    ...(opts.containerId ? { containerId: opts.containerId } : {}),
  });
}

function addBox(id, x, y, w, h, opts = {}) {
  elements.push({
    type: "rectangle", id, x, y, width: w, height: h,
    backgroundColor: opts.bg ?? "transparent",
    fillStyle: "solid",
    roundness: { type: 3 },
    strokeColor: opts.stroke ?? "#1e1e1e",
    strokeWidth: opts.strokeWidth ?? 2,
    ...(opts.strokeStyle ? { strokeStyle: opts.strokeStyle } : {}),
    ...(opts.opacity != null ? { opacity: opts.opacity } : {}),
  });
}

function addArrow(id, x, y, points, opts = {}) {
  const allPoints = [[0, 0], ...points];
  const lastPt = allPoints[allPoints.length - 1];
  elements.push({
    type: "arrow", id, x, y,
    width: lastPt[0], height: lastPt[1],
    points: allPoints,
    endArrowhead: opts.head ?? "arrow",
    strokeWidth: opts.strokeWidth ?? 2,
    strokeColor: opts.color ?? "#1e1e1e",
    ...(opts.dash ? { strokeStyle: "dashed" } : {}),
  });
}

function addArrowLabel(arrowId, x, y, text, opts = {}) {
  addText(`${arrowId}_l`, x, y, text, {
    fontSize: opts.fontSize ?? 14,
    color: opts.color ?? "#757575",
    containerId: arrowId,
  });
}

// ─── Layout constants ──────────────────────────────────────────────────

// Left column center (Packer, AMI, inside-EC2 elements)
const LCX = 300;
// External services column
const EXT_X = 720;
// EC2 zone bounds
const EC2 = { x: 50, y: 350, w: 610, h: 460 };

// ─── TITLE ─────────────────────────────────────────────────────────────

addText("title", 190, 0, "Teleport Agent — EC2 Components", {
  fontSize: 28, align: "left",
});

// ─── ROW 1: Packer ─────────────────────────────────────────────────────

addImage("ico_packer", icons.packer.id, LCX - ICON / 2, 55, ICON);
addText("ico_packer_l", LCX - 36, 55 + ICON + 4, "Packer", { fontSize: 18 });

// Arrow: Packer → AMI
addArrow("a_packer_ami", LCX, 145, [[0, 55]]);

// ─── ROW 2: AMI ────────────────────────────────────────────────────────

addImage("ico_ami", icons.ami.id, LCX - ICON / 2, 205, ICON);
addText("ico_ami_l", LCX - 18, 205 + ICON + 4, "AMI", { fontSize: 18 });

// Arrow: AMI → EC2 zone (down)
addArrow("a_ami_ec2", LCX, 295, [[0, 55]]);

// Arrow: AMI → Parameter Store (right)
addArrow("a_ami_ps", LCX + ICON / 2 + 10, 237, [[320, 0]]);

// ─── EXTERNAL: Parameter Store (right, upper) ─────────────────────────

addImage("ico_ps", icons.paramStore.id, EXT_X, 210, ICON_SM);
addText("ico_ps_l", EXT_X - 20, 210 + ICON_SM + 4, "Parameter Store", { fontSize: 16 });
addText("ps_detail", EXT_X - 15, 210 + ICON_SM + 24, "teleport-etc/contents", {
  fontSize: 13, color: "#757575",
});

// ─── EXTERNAL: Secrets Manager (right, lower) ─────────────────────────

addImage("ico_sm", icons.secretsMgr.id, EXT_X, 440, ICON_SM);
addText("ico_sm_l", EXT_X - 20, 440 + ICON_SM + 4, "Secrets Manager", { fontSize: 16 });
addText("sm_detail", EXT_X - 5, 440 + ICON_SM + 24, "dd-agent-api-key", {
  fontSize: 13, color: "#757575",
});

// ─── EC2 INSTANCE ZONE (dashed green box) ──────────────────────────────

addBox("ec2_zone", EC2.x, EC2.y, EC2.w, EC2.h, {
  bg: "#d3f9d8", stroke: "#22c55e", strokeWidth: 2,
  strokeStyle: "dashed", opacity: 25,
});

// EC2 icon + label in top-left corner of zone
addImage("ico_ec2z", icons.ec2.id, EC2.x + 15, EC2.y + 8, 28);
addText("ec2z_l", EC2.x + 48, EC2.y + 10, "EC2 Instance", {
  fontSize: 20, color: "#15803d", align: "left",
});

// Zone sublabel
addText("ec2z_sub", EC2.x + 48, EC2.y + 34, "teleport agent", {
  fontSize: 16, color: "#22c55e", align: "left",
});

// ─── Inside EC2 — Row 1: confd, confd config, init ────────────────────

const R1Y = 420;

// confd (icon + label)
addImage("ico_confd", icons.confd.id, 110, R1Y, ICON_SM);
addText("ico_confd_l", 110, R1Y + ICON_SM + 4, "confd", { fontSize: 18 });

// confd config (box)
addBox("confd_cfg", 270, R1Y + 4, 160, 46, { bg: "#ffd8a8", stroke: "#f59e0b" });
addText("confd_cfg_l", 290, R1Y + 14, "confd config", {
  fontSize: 16, containerId: "confd_cfg",
});

// init (box)
addBox("init_box", 490, R1Y + 4, 120, 46, { bg: "#a5d8ff", stroke: "#4a9eed" });
addText("init_l", 515, R1Y + 14, "init", {
  fontSize: 18, containerId: "init_box",
});

// Arrow: confd config → confd (left)
addArrow("a_cfg_confd", 270, R1Y + 27, [[-112, 0]], { color: "#f59e0b" });

// Arrow: init → confd config (left)
addArrow("a_init_cfg", 490, R1Y + 27, [[-60, 0]], { color: "#4a9eed" });

// ─── Arrow: Parameter Store → confd (dashed, from outside into EC2) ───

// Route: down from PS, then left into EC2 zone to confd
addArrow("a_ps_confd", EXT_X + ICON_SM / 2, 285, [[0, 80], [-506, 160]], {
  color: "#22c55e", dash: true,
});
addArrowLabel("a_ps_confd", EXT_X - 150, 365, "reads config");

// ─── Arrow: Secrets Manager → init (dashed, from outside into EC2) ────

addArrow("a_sm_init", EXT_X, R1Y + 27 + 4, [[-90, 0]], {
  color: "#ef4444", dash: true,
});

// ─── Inside EC2 — Row 2: /etc/teleport.yaml, agent config ────────────

const R2Y = 545;

// /etc/teleport.yaml
addBox("yaml_box", 75, R2Y, 200, 50, { bg: "#c3fae8", stroke: "#06b6d4" });
addText("yaml_l", 85, R2Y + 12, "/etc/teleport.yaml", {
  fontSize: 18, containerId: "yaml_box",
});

// agent config (for DataDog)
addBox("agent_cfg", 370, R2Y, 180, 50, { bg: "#ffd8a8", stroke: "#f59e0b" });
addText("agent_cfg_l", 390, R2Y + 12, "agent config", {
  fontSize: 16, containerId: "agent_cfg",
});

// Arrow: confd → /etc/teleport.yaml (down)
addArrow("a_confd_yaml", 134, R1Y + ICON_SM, [[0, R2Y - R1Y - ICON_SM]], {
  color: "#f59e0b",
});
addArrowLabel("a_confd_yaml", 144, R1Y + ICON_SM + 20, "renders");

// Arrow: init → agent config (down)
addArrow("a_init_agcfg", 550, R1Y + 50, [[-90, R2Y - R1Y - 50]], {
  color: "#4a9eed",
});

// ─── Inside EC2 — Row 3: teleport agent, datadog agent ────────────────

const R3Y = 670;

// teleport agent
addImage("ico_tp", icons.teleport.id, 143, R3Y, ICON);
addText("ico_tp_l", 100, R3Y + ICON + 4, "teleport agent", { fontSize: 18 });

// datadog agent
addImage("ico_dd", icons.datadog.id, 428, R3Y, ICON);
addText("ico_dd_l", 393, R3Y + ICON + 4, "datadog agent", { fontSize: 18 });

// Arrow: /etc/teleport.yaml → teleport agent (down)
addArrow("a_yaml_tp", 175, R2Y + 50, [[0, R3Y - R2Y - 50]], {
  color: "#8b5cf6",
});

// Arrow: agent config → datadog agent (down)
addArrow("a_agcfg_dd", 460, R2Y + 50, [[0, R3Y - R2Y - 50]], {
  color: "#ec4899",
});

// ─── LEGEND: Teleport services (bottom-right, outside EC2 zone) ─────

const LEG_X = 700;
const LEG_Y = 600;
const LEG_W = 170;
const LEG_ROW = 38;
const legServices = ["SSH service", "DB service", "App service", "Discovery service"];

// Legend header
addBox("leg_hdr", LEG_X, LEG_Y, LEG_W, 42, { bg: "#d0bfff", stroke: "#7c3aed" });
addText("leg_hdr_l", LEG_X + 10, LEG_Y + 8, "Teleport Agent", {
  fontSize: 18, containerId: "leg_hdr", color: "#5b21b6",
});

// Stacked service rows
legServices.forEach((svc, i) => {
  const sy = LEG_Y + 42 + i * LEG_ROW;
  addBox(`leg_svc_${i}`, LEG_X, sy, LEG_W, LEG_ROW, {
    bg: "#e9ecef", stroke: "#7c3aed", strokeWidth: 1,
  });
  addText(`leg_svc_${i}_l`, LEG_X + 10, sy + 8, svc, {
    fontSize: 15, containerId: `leg_svc_${i}`,
  });
});

// ─── Build document ────────────────────────────────────────────────────

const doc = {
  type: "excalidraw",
  version: 2,
  source: "https://excalidraw.com",
  elements,
  appState: { viewBackgroundColor: "#ffffff", gridSize: null },
  files,
};

const outPath = join(__dirname, "component-diagram.excalidraw");
writeFileSync(outPath, JSON.stringify(doc, null, 2));
console.log(`Written to ${outPath}`);
console.log(`${elements.length} elements, ${Object.keys(files).length} embedded files`);
