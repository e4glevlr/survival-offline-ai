#!/bin/bash
# Copies the reviewed illustrations into the app bundle: 1024 px wide JPEG, ~70% quality (~100 KB each).
cd "$(dirname "$0")"
RES=../../../ios/ResQKit/Sources/ResQUI/Resources
for f in *.jpg; do
  sips -s format jpeg -s formatOptions 70 --resampleWidth 1024 "$f" --out "$RES/cover-$f" >/dev/null
done
du -ch "$RES"/cover-*.jpg | tail -1
