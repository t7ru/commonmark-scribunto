#!/bin/bash

OUT="dist/markdown.lua"

mkdir -p "${OUT%/*}"
shopt -s nullglob
files=(src/*.lua)

cat << 'EOF' > "$OUT"
-- Version:	1.1
-- License:	MIT
-- Author:	t7ru [[User:Gabonnie]]
local _modules = {}
local _base_require = require
local function require(name)
    if _modules[name] then return _modules[name] end
    return _base_require(name)
end

EOF

for f in "${files[@]}"; do
    mod=$(basename "$f" .lua)
    echo "_modules['$mod'] = (function()" >> "$OUT"
    awk -v RS='^$' '{gsub(/^[[:space:]]+|[[:space:]]+$/,""); printf "%s", $0}' "$f" >> "$OUT"
    printf "\nend)()\n\n" >> "$OUT"
done
printf "return _modules['%s']\n" "$(basename "${files[-1]}" .lua)" >> "$OUT"

echo "Built $OUT from ${#files[@]} files:"
printf "  %s\n" "${files[@]##*/}"
