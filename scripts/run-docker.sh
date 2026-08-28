#!/usr/bin/env sh
set -eu

IMAGE="${IMAGE:-ghcr.io/zongpc/ldp-gem5:micro26-final}"
PROFILE="${1:-fast}"
JOBS="${JOBS:-4}"
CONTAINER="ldp-ae-${PROFILE}-$$"
OUTPUT_DIR="${RESULTS_DIR:-results}"

case "$PROFILE" in
    fast|full) ;;
    *)
        echo "usage: $0 [fast|full]" >&2
        exit 2
        ;;
esac

docker create \
    --name "$CONTAINER" \
    --platform linux/amd64 \
    "$IMAGE" \
    --run-profile "$PROFILE" --jobs "$JOBS" >/dev/null

if ! docker start -a "$CONTAINER"; then
    echo "Run failed; retained container: $CONTAINER" >&2
    exit 1
fi

if [ -e "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="${OUTPUT_DIR}-${PROFILE}-$(date +%Y%m%d-%H%M%S)-$$"
    echo "Existing output path detected; exporting to: $OUTPUT_DIR"
fi
mkdir -p "$OUTPUT_DIR"
if ! docker cp "$CONTAINER:/results/." "$OUTPUT_DIR/"; then
    echo "Export failed; retained container: $CONTAINER" >&2
    exit 1
fi
docker rm "$CONTAINER" >/dev/null
OUTPUT_ABS="$(cd "$OUTPUT_DIR" && pwd)"
echo "Results copied to: $OUTPUT_ABS/$PROFILE"
