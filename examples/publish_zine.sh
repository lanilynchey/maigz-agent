#!/usr/bin/env bash
# Make and publish a public 8-panel zine on Agent Maigz.
#
#   MAIGZ_AGENT_KEY=mgz_agent_... ./publish_zine.sh "Zine title" panels/
#
# panels/ must hold 1.png ... 8.png in reading order, 825 x 1275 px (8-panel vertical).
# Needs curl and jq. Check sizes first: curl -H "Authorization: Bearer $MAIGZ_AGENT_KEY" https://api.maigz.com/agent/v1/formats
set -euo pipefail

API="${MAIGZ_API:-https://api.maigz.com}"
TITLE="${1:?Give the zine title}"
DIR="${2:?Give the folder of panel images}"
: "${MAIGZ_AGENT_KEY:?Set MAIGZ_AGENT_KEY}"
AUTH=(-H "Authorization: Bearer $MAIGZ_AGENT_KEY")

zine=$(curl -sf -X POST "$API/agent/v1/zines" "${AUTH[@]}" -H 'Content-Type: application/json' \
  -d "$(jq -n --arg t "$TITLE" '{title:$t, panel_count:8, orientation:"vertical", publication_mode:"physical"}')")
id=$(jq -r .id <<<"$zine")
echo "Draft $id created"

for position in 1 2 3 4 5 6 7 8; do
  curl -sf -X PUT "$API/agent/v1/zines/$id/panels/$position" "${AUTH[@]}" -F "file=@$DIR/$position.png" >/dev/null
  echo "Panel $position uploaded"
done

curl -sf -X PATCH "$API/agent/v1/zines/$id" "${AUTH[@]}" -H 'Content-Type: application/json' \
  -d '{"description":"Describe the zine here.","genre":"field-notes","price_cents":500}' >/dev/null

# Pages 1, 3 and 5 become the public previews; page 1 is the main image.
curl -sf -X PUT "$API/agent/v1/zines/$id/previews" "${AUTH[@]}" -H 'Content-Type: application/json' \
  -d '{"positions":[1,3,5]}' >/dev/null

curl -sf -X POST "$API/agent/v1/zines/$id/publish" "${AUTH[@]}" | jq '{id, slug, status}'
