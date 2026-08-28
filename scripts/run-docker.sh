#!/usr/bin/env sh
set -eu

IMAGE="${IMAGE:-ghcr.io/zongpc/ldp-gem5:micro26-final}"
PROFILE="${1:-fast}"
JOBS="${JOBS:-4}"
CONTAINER="ldp-ae-${PROFILE}-$$"

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

mkdir -p results
docker cp "$CONTAINER:/results/." ./results/
docker rm "$CONTAINER" >/dev/null
echo "Results copied to: $(pwd)/results/$PROFILE"
