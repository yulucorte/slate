#!/usr/bin/env bash
# Mueve una tarjeta (FEAT-NNN o BUG-NNN) entre los archivos de estado de slate,
# validando las reglas en vez de dejarlas a la memoria del agente.
#
# Uso: move-card.sh <ID> <destino>
#   FEAT: backlog | in-progress | done      BUG: fixed
# Exito: una linea "FEAT-012: in-progress.md -> done.md", exit 0.
# Rechazo: motivo en stderr, exit 1, ningun archivo modificado.
# Uso incorrecto: exit 2.
#
# Reglas: backlog -> done prohibido (pasar por in-progress); done.md / fixed.md
# son inmutables; a done exige subtareas [x] (o [-] con "-> FEAT-YYY" /
# "(descartada: motivo)") y Verified con fecha; a fixed exige Fix, Commit y
# Fixed no vacios ni "none".
set -uo pipefail

[ $# -eq 2 ] || { echo "move-card: uso: move-card.sh <ID> <destino>" >&2; exit 2; }

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

MC_ROOT="$ROOT" python3 - "$1" "$2" <<'PY'
import os, re, sys, datetime

card_id, dest = sys.argv[1], sys.argv[2]
root = os.environ["MC_ROOT"]
today = datetime.date.today().isoformat()

m = re.fullmatch(r"(FEAT|BUG)-\d+", card_id)
if not m:
    print("move-card: ID invalido '%s' (esperado FEAT-NNN o BUG-NNN)" % card_id, file=sys.stderr)
    sys.exit(2)
prefix = m.group(1)

if prefix == "FEAT":
    folder, names = "features", ["backlog", "in-progress", "done"]
    status_of = {"backlog": "backlog", "in-progress": "in_progress", "done": "done"}
    frozen = "done"
else:
    folder, names = "bugs", ["open", "fixed"]
    status_of = {"open": "open", "fixed": "fixed"}
    frozen = "fixed"
if dest not in names or dest == "open":
    print("move-card: destino invalido '%s' para %s (validos: %s)"
          % (dest, prefix, ", ".join(n for n in names if n != "open")), file=sys.stderr)
    sys.exit(2)


def path(name):
    return os.path.join(root, "docs", "slate", folder, name + ".md")


def read_blocks(name):
    """(cabecera, [bloques]); un bloque va de '## ' al siguiente '## ' o al fin."""
    try:
        lines = open(path(name), encoding="utf-8").read().split("\n")
    except OSError:
        return None
    head, blocks = [], []
    for ln in lines:
        if ln.startswith("## "):
            blocks.append([ln])
        elif blocks:
            blocks[-1].append(ln)
        else:
            head.append(ln)
    return head, blocks


def die(msg):
    print("move-card: " + msg, file=sys.stderr)
    sys.exit(1)


src = None
for name in names:
    rb = read_blocks(name)
    if rb is None:
        continue
    for i, b in enumerate(rb[1]):
        if re.match(r"## %s:" % re.escape(card_id), b[0]):
            src = (name, rb, i)
if src is None:
    die("%s no existe en %s" % (card_id, ", ".join(n + ".md" for n in names)))
sname, (shead, sblocks), idx = src
block = sblocks[idx]

if sname == frozen:
    die("%s ya esta en %s.md: es inmutable (crea una tarjeta nueva con Supersedes)" % (card_id, frozen))
if sname == dest:
    die("%s ya esta en %s.md" % (card_id, dest))
if prefix == "FEAT" and sname == "backlog" and dest == "done":
    die("backlog -> done esta prohibido: pasa por in-progress")


def field(label):
    for ln in block:
        mm = re.match(r"- \*\*%s\*\*:\s*(.*)$" % re.escape(label), ln)
        if mm:
            return mm.group(1).strip()
    return None


if prefix == "FEAT" and dest == "done":
    bad = []
    for ln in block:
        mm = re.match(r"\s*- \[(.)\]", ln)
        if not mm:
            continue
        if mm.group(1) == "x":
            continue
        if mm.group(1) == "-" and re.search(r"(→|->)\s*FEAT-\d+|\(descartada:", ln):
            continue
        bad.append(ln.strip())
    if bad:
        die("subtareas sin cerrar o [-] sin '-> FEAT-YYY' / '(descartada: motivo)':\n  " + "\n  ".join(bad))
    v = field("Verified")
    if not v or not re.match(r"\d{4}-\d{2}-\d{2}", v):
        die("falta '- **Verified**: AAAA-MM-DD'")

if prefix == "BUG" and dest == "fixed":
    for label in ("Fix", "Commit", "Fixed"):
        v = field(label)
        if not v or v.lower() == "none":
            die("falta '%s' (vacio o 'none')" % label)


def set_field(label, value, insert=True):
    for i, ln in enumerate(block):
        if re.match(r"- \*\*%s\*\*:" % re.escape(label), ln):
            block[i] = "- **%s**: %s" % (label, value)
            return
    if insert:
        # tras la ultima linea de campo "- **...**:" contigua al titulo
        pos = 1
        while pos < len(block) and block[pos].startswith("- **"):
            pos += 1
        block.insert(pos, "- **%s**: %s" % (label, value))


set_field("Status", status_of[dest])
set_field("Updated", today, insert=(prefix == "FEAT"))
while block and block[-1].strip() == "":
    block.pop()

# Destino: se agrega al final; origen: se quita el bloque.
rb = read_blocks(dest)
if rb is None:
    die("no existe %s" % path(dest))
dhead, dblocks = rb
dtext = open(path(dest), encoding="utf-8").read()
dtext = dtext.rstrip("\n") + "\n\n" + "\n".join(block) + "\n"
del sblocks[idx]
parts = list(shead)
for b in sblocks:
    parts.extend(b)
stext = "\n".join(parts).rstrip("\n") + "\n"


def write(p, text):
    tmp = p + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, p)


write(path(dest), dtext)
write(path(sname), stext)
print("%s: %s.md -> %s.md" % (card_id, sname, dest))
PY
