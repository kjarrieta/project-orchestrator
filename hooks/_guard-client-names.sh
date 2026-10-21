#!/bin/sh
# Cuerpo compartido de pre-commit y commit-msg: bloquea que un nombre de
# cliente/proyecto cruce al repo PUBLICO de la skill (project-orchestrator).
# Los aprendizajes con procedencia de proyecto van SOLO al repo privado
# project-orchestrator-memory; aqui el conocimiento viaja generico, sin
# atribucion identificable (ver references/feedback.md).
#
# Origen de la regla (2026-10-21): "ONEGROUP backend-sincronizador" se filtro
# a este repo publico via /learn-from (commits que terminaron reescritos con
# git-filter-repo tras detectarlo). Los dos tokens quedan bloqueados a
# perpetuidad abajo, sin depender de que guarded-projects.json los liste.
#
# $1: texto a escanear (diff en crudo, o archivo de mensaje de commit).

text_file="$1"
[ -f "$text_file" ] || exit 0

tokens_file=$(mktemp 2>/dev/null) || exit 0
trap 'rm -f "$tokens_file"' EXIT

printf '%s\n%s\n' "ONEGROUP" "backend-sincronizador" > "$tokens_file"

guarded="$HOME/.claude/project-orchestrator/memory/guarded-projects.json"
if [ -f "$guarded" ]; then
  grep -o '"ruta"[^,}]*' "$guarded" \
    | sed -E 's/.*"ruta"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' \
    | tr '/' '\n' \
    | grep -viE '^(c:|xampp|htdocs|clientes|make2|20[0-9][0-9])$' \
    | grep -v '^$' \
    >> "$tokens_file"
fi

sort -u -o "$tokens_file" "$tokens_file"

hit=0
while IFS= read -r t; do
  [ -z "$t" ] && continue
  match=$(grep -niF "$t" "$text_file")
  if [ -n "$match" ]; then
    hit=1
    echo "BLOQUEADO: se nombra '$t' (identificador de proyecto/cliente) en este repo PUBLICO." >&2
    printf '%s\n' "$match" | sed 's/^/  /' >&2
  fi
done < "$tokens_file"

if [ "$hit" -eq 1 ]; then
  echo >&2
  echo "project-orchestrator es publico; project-orchestrator-memory es privado." >&2
  echo "Mueve la procedencia (nombre de cliente/proyecto) al repo privado y deja" >&2
  echo "aqui solo el patron generico. Ver references/feedback.md." >&2
  echo "Si es un falso positivo confirmado: git commit --no-verify" >&2
  exit 1
fi

exit 0
