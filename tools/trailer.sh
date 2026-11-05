#!/usr/bin/env bash
# Records the trailer (tools/trailer.gd) with Movie Maker in a window, about 25 min of PNG frames, then encodes
# builds/trailer/the-condo-trailer.mp4 at about -18 LUFS, writes builds/trailer/report.txt and sheet.png, and
# exits 1 if a check fails. raw/ (the frames and WAV) is deleted only when every check passes.
#   tools/trailer.sh [--encode-only]   (--encode-only reuses builds/trailer/raw/ and render.log)
# GODOT defaults to the binary on PATH.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
out=builds/trailer
raw=$out/raw
mp4=$out/the-condo-trailer.mp4

case "${1:-}" in
  "")
    # Movie Maker records at the project's window size, not --resolution: 1920x1080 needs a window override.
    if [ -e override.cfg ]; then echo "override.cfg already exists: not overwriting it"; exit 1; fi
    trap 'rm -f override.cfg' EXIT
    printf '[display]\nwindow/size/window_width_override=1920\nwindow/size/window_height_override=1080\n' > override.cfg
    rm -rf "$raw"
    mkdir -p "$raw"
    "$GODOT" --path . --resolution 1920x1080 --write-movie "$PWD/$raw/frame.png" --quit-after 4500 \
      --script res://tools/trailer.gd 2>&1 | tee "$out/render.log" || { echo "render failed"; exit 1; }
    rm -f override.cfg
    trap - EXIT
    ;;
  --encode-only) ;;
  *) echo "usage: tools/trailer.sh [--encode-only]" >&2; exit 2 ;;
esac
if grep -q "SCRIPT ERROR" "$out/render.log"; then echo "script errors in $out/render.log"; exit 1; fi

read -r first count < <(sed -n 's/^TRAILER_FRAMES //p' "$out/render.log") \
  || { echo "no TRAILER_FRAMES line in $out/render.log"; exit 1; }
S=$(awk -v f="$first" 'BEGIN { printf "%.6f", f / 60 }')
LEN=$(awk -v c="$count" 'BEGIN { printf "%.6f", c / 60 }')

# Prints "<integrated LUFS> <true peak dBTP>" from ebur128's summary for the given input arguments.
loudness() {
  ffmpeg -nostdin -hide_banner -nostats "$@" -af ebur128=peak=true:framelog=quiet -f null - 2>&1 \
    | awk '/Summary:/ { s = 1 } s && $1 == "I:" { i = $2 } s && $1 == "Peak:" { p = $2 } END { print i, p }'
}

read -r in_i in_tp < <(loudness -ss "$S" -t "$LEN" -i "$raw/frame.wav")
[ -n "$in_tp" ] || { echo "no loudness summary for $raw/frame.wav"; exit 1; }
gain=$(awk -v i="$in_i" 'BEGIN { printf "%.2f", -18 - i }')
fade_out=$(awk -v l="$LEN" 'BEGIN { printf "%.3f", l - 1.5 }')

# One fixed gain, then the limiter holds back only the hits (limit 0.75 = -2.5 dBFS, under -1 dBTP after AAC).
ffmpeg -nostdin -hide_banner -loglevel error -y \
  -framerate 60 -start_number "$first" -i "$raw/frame%08d.png" -ss "$S" -t "$LEN" -i "$raw/frame.wav" \
  -frames:v "$count" \
  -af "volume=${gain}dB,alimiter=limit=0.75:attack=5:release=80:level=0:latency=1,afade=t=in:d=0.5,afade=t=out:st=${fade_out}:d=1.5,aresample=48000" \
  -c:v libx264 -preset slow -crf 16 -tune grain -pix_fmt yuv420p -c:a aac -b:a 256k -movflags +faststart "$mp4"

IFS=, read -r vcodec width height pixfmt < <(ffprobe -v error -select_streams v:0 \
  -show_entries stream=codec_name,width,height,pix_fmt -of csv=p=0 "$mp4")
IFS=, read -r acodec rate < <(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,sample_rate \
  -of csv=p=0 "$mp4")
dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$mp4")
read -r out_i out_tp < <(loudness -i "$mp4" -vn)
limit=$(awk -v a="$in_tp" -v g="$gain" -v b="$out_tp" 'BEGIN { printf "%.2f", a + g - b }')
{
  echo "ffprobe: $vcodec ${width}x${height} $pixfmt, $acodec $rate Hz, $dur s"
  echo "input:   I $in_i LUFS, TP $in_tp dBTP (movie frames $first + $count, ${S} s + ${LEN} s of frame.wav)"
  echo "gain:    $gain dB"
  echo "output:  I $out_i LUFS, TP $out_tp dBTP"
  echo "limiting: $limit dB (input TP + gain - output TP)"
} > "$out/report.txt"

# The contact sheet before the checks, so a failed run still has one to look at.
sel=""
for t in 1.0 7 12.5 17.5 21 25 28 31 34.5 37.5 40.5 44 48 49.45 52.5 55 59 61; do
  sel+=$(awk -v t="$t" 'BEGIN { printf "eq(n,%d)+", t * 60 + 0.5 }')
done
ffmpeg -nostdin -hide_banner -loglevel error -y -i "$mp4" -vf "select='${sel%+}',scale=480:-1,tile=6x3" \
  -frames:v 1 -update 1 "$out/sheet.png"

fails=$(awk -v w="$width" -v h="$height" -v d="$dur" -v vc="$vcodec" -v pf="$pixfmt" -v ac="$acodec" -v r="$rate" \
  -v i="$out_i" -v tp="$out_tp" -v l="$limit" 'BEGIN {
  if (w != 1920 || h != 1080) print "FAIL size " w "x" h
  if (d < 55 || d > 65) print "FAIL duration " d
  if (vc != "h264" || pf != "yuv420p" || ac != "aac" || r != 48000) print "FAIL codecs " vc " " pf " " ac " " r
  if (i == "" || i < -19 || i > -17) print "FAIL integrated loudness " i
  if (tp == "" || tp > -1.0) print "FAIL true peak " tp
  if (l > 6) print "FAIL limiting " l
}')
echo "${fails:-checks: pass}" >> "$out/report.txt"
cat "$out/report.txt"
[ -z "$fails" ] || exit 1
rm -rf "$raw"
