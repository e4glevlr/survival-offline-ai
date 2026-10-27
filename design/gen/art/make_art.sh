#!/bin/bash
# Guide article illustrations via the Antigravity CLI (agy). One run per pillar so each set
# stays stylistically coherent. Output: design/gen/art/<article-id>.jpg
# (JPEG bytes, 1376x768). Images already on disk are skipped, so a rerun only fills gaps; move a bad
# one to rejected/ to redo it. Look at every image before shipping. Then ./ship_art.sh downsizes them into ResQUI/Resources/cover-<id>.jpg.
# Usage: ./make_art.sh [pillar...]   (fire water food shelter nav aid; default all)
cd "$(dirname "$0")"
OUT="$PWD"
STYLE="Shared visual language for every image: high-end illustrated field manual, painterly digital gouache with crisp clean silhouettes, subtle paper grain, soft directional light; palette of deep charcoal, moss green, warm ochre and ember orange, cool slate blue for water; dark muted background so the image sits on a near-black app UI; the subject large, centered and easy to read at phone size. Every image is 16:9 widescreen landscape aspect ratio. Absolutely no text, letters, numbers, labels, arrows, watermark or logo in any image."

run() { # pillar, numbered list; items whose file already exists are skipped
  local todo=$(while IFS= read -r l; do f=${l#*. }; f=${f%% —*}; [ -e "$f" ] || echo "$l"; done <<<"$2")
  [ -z "$todo" ] && return
  agy -p "Generate exactly $(grep -c '^[0-9]' <<<"$todo") images with generate_image, one call per image, saving each to the EXACT absolute path given:
$todo
$STYLE
Then run: ls -la $OUT. Do nothing else." \
    --model "Gemini 3.8 Flash (Low)" --dangerously-skip-permissions --add-dir "$OUT" --print-timeout 20m \
    >"$OUT/log-$1.txt" 2>&1
}

fire="1. $OUT/fire-site.jpg — a safe campfire spot: a small cleared circle of bare soil ringed with stones on flat ground, well away from overhanging branches and a tent, dry leaves swept aside, at dusk in a forest clearing.
2. $OUT/fire-lay.jpg — instructional side-by-side of two unlit-then-lit fire lays on bare ground: left, a teepee cone of thin kindling sticks leaning around a fist-sized nest of dry tinder with a small gap on one side and a small flame inside; right, a log-cabin pyramid of crossed layers of sticks narrowing upward with a small fire burning on the very top. Both clearly separated, three-quarter view.
3. $OUT/fire-no-match.jpg — close-up of hands striking a ferro rod with a knife spine, a shower of bright sparks landing on a nest of dry tinder, next to a 9V battery and steel wool glowing orange.
4. $OUT/fire-bow-drill.jpg — instructional three-quarter view of a bow drill in use: a kneeling person's hands, one pressing a palm-sized stone bearing block on top of a vertical wooden spindle, the other hand pulling a curved bow sideways; the bow's taut string wraps one full turn around the middle of the spindle, clearly drawn passing in front of the spindle and back behind it so the loop is visible (no knot on the spindle, the bow never touches the spindle); the spindle's lower tip sits in a shallow round blackened socket on the top face of a flat softwood fireboard (it does not pass through the board), a V-shaped notch cut from the board's edge into the socket, the board held down by the person's foot, a smoking dark ember pile on a leaf under the notch.
5. $OUT/fire-keep-out.jpg — a campfire banked for the night with large logs and a bed of glowing coals, and beside it a pot pouring water onto a doused fire pit sending up steam.
6. $OUT/warmth.jpg — a person in wet rain gear huddled under a tarp by a small fire, wrapped in a blanket, sitting on a thick bed of branches off the cold ground, steam rising from drying socks."

water="1. $OUT/water-purify.jpg — a blackened metal pot of water at a rolling boil over a campfire, next to clear plastic bottles of water lying on a sunny rock (solar disinfection).
2. $OUT/water-find.jpg — a lush green valley floor with a thin stream at the base of a slope, animal tracks leading to it, dense green vegetation and insects marking the water line.
3. $OUT/water-still-bag.jpg — a clear plastic bag tied over a leafy green tree branch in bright sun, droplets of condensation inside and a small pool of water collected in the lowest corner of the bag.
4. $OUT/water-still-pit.jpg — instructional cross-section cutaway of a solar still dug in the ground: a bowl-shaped pit, a cup standing upright at the bottom center, a sheet of clear plastic stretched over the pit and sealed with soil around the rim, a small stone in the middle of the plastic making it sag into a cone right above the cup, water droplets on the underside running down into the cup, a thin tube running from the cup up over the rim. Bright sun above, earth layers visible in the cut.
5. $OUT/water-ration.jpg — a hiker sitting in shade sipping water from a bottle in small sips, a canteen and a packet of oral rehydration salts beside them, hot dry landscape behind."

food="1. $OUT/food-insects.jpg — edible forest foods laid on a broad green leaf: earthworms, snails, crickets and grubs, next to a small cooking fire with a few roasting on a stick.
2. $OUT/food-plants.jpg — a hand holding a single unknown wild leaf at arm's length in a dense forest understory, red berries and mushrooms around, a cautious mood.
3. $OUT/food-shellfish.jpg — hands turning over a rock in a clear shallow rocky stream revealing a freshwater crab and snails, a small mesh bag beside.
4. $OUT/food-fishing.jpg — improvised fishing: a bent safety-pin hook and line tied to a bamboo pole, a cork float on a calm forest river at golden hour.
5. $OUT/food-traps.jpg — a simple trap set along a faint animal trail at the base of a tree, smeared with mud to hide scent, leaf litter around, low angle.
6. $OUT/food-fish-prep.jpg — a fresh fish with bright clear eyes and red gills on a flat stone beside a knife, being cleaned at a riverside."

shelter="1. $OUT/shelter-site.jpg — a flat raised spot on a gentle forest slope chosen for camp, safely above a stream, away from dead overhanging branches, with a dry riverbed and flood debris visible lower down.
2. $OUT/shelter-tarp.jpg — a taut A-frame tarp shelter strung on a ridgeline between two trees, corners staked with guy lines, light rain falling.
3. $OUT/shelter-leanto.jpg — a lean-to made of a horizontal pole between two trees with many branches leaning against it and covered in leaves, a small fire in front.
4. $OUT/shelter-debris.jpg — instructional side three-quarter view of a debris hut: one long straight ridge pole that slopes diagonally, its front end resting in the fork of a waist-high stump and its back end on the ground, so the hut is a long low wedge, tallest at the entrance and touching the ground at the far end; many sticks leaning against both sides of the ridge pole as ribs; the back half shown as a cutaway revealing an arm's-length-thick layer of dry leaves piled over the ribs and a thick leaf bed inside; a pile of leaves beside the entrance. No ladder, no lattice, no horizontal ridge.
5. $OUT/shelter-raised.jpg — a raised bed platform of lashed poles about knee height above wet jungle ground, covered with leaves, under a tarp.
6. $OUT/knots.jpg — five different knots tied in thick orange paracord laid on a dark wooden plank, flat lay from above: bowline, clove hitch, taut-line hitch, square knot, figure-eight."

nav="1. $OUT/nav-shadow.jpg — instructional top-down view of a shadow-stick compass on flat sunlit dirt: a straight one-metre stick upright, its shadow on the ground, one small stone marking an earlier shadow tip and a second stone marking the later shadow tip, a straight line scratched in the dirt joining the two stones. Bird's-eye view, clean ground.
2. $OUT/nav-watch.jpg — a hand holding an analog wristwatch flat, the hour hand pointed at the low sun, forest ridge behind.
3. $OUT/nav-stars.jpg — a night sky over a dark forest ridge with the Big Dipper clearly visible and the Southern Cross low on the horizon, a crescent moon, a lone person looking up.
4. $OUT/nav-compass.jpg — a magnetised sewing needle floating on a leaf in a small bowl of water, a silk cloth beside it, close-up.
5. $OUT/nav-signal.jpg — instructional aerial view of a forest clearing used for rescue signalling: a giant X made of logs and bright clothing on the grass, three signal fires arranged in a triangle sending up white smoke, a small figure flashing a mirror toward a distant helicopter.
6. $OUT/nav-lost.jpg — a lost hiker sitting calmly on a log at a trail junction in mist, pausing with a map and whistle, stopping to think."

aid="1. $OUT/aid-wound.jpg — hands cleaning a small scrape on a knee with clean water from a bottle, then a sterile bandage on a first-aid pouch beside.
2. $OUT/aid-sprain.jpg — an ankle wrapped in an elastic bandage in a figure-eight, propped up on a backpack, a cold wet cloth beside.
3. $OUT/aid-sting.jpg — a bee on a forearm with a red welt, and a card edge scraping out a stinger, close-up.
4. $OUT/aid-leech.jpg — a leech on a lower leg above a hiking sock, a fingernail sliding under its narrow end to detach it, close-up.
5. $OUT/aid-ors.jpg — preparing oral rehydration solution: a litre bottle of clean water, a small pile of sugar and a pinch of salt on a spoon being added.
6. $OUT/aid-recovery.jpg — instructional bird's-eye view of an adult lying on their side on a mat in the first-aid recovery position: the lower arm stretched out at a right angle to the body palm up, the upper hand's back resting under the cheek, the upper leg bent at the hip and knee at a right angle resting on the ground in front, head tilted slightly back with the mouth pointing toward the ground. Anatomically correct, calm, fully clothed."

# One pillar at a time: parallel runs burned the image quota in a minute (429 RESOURCE_EXHAUSTED).
for p in "${@:-fire water food shelter nav aid}"; do
  for q in $p; do run "$q" "${!q}"; done
done
ls -la "$OUT"/*.jpg
