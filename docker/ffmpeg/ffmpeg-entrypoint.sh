#!/bin/sh
set -eu

CONF_FILE="/app/configure.conf"
. "$CONF_FILE"

: "${CAMERA_ID:?CAMERA_ID is not configured}"

CAMERA_PATH="/host-dev/v4l/by-id/$CAMERA_ID"


while [ ! -e "$CAMERA_PATH" ]; do
    echo "Waiting for camera..."
    sleep 2
done

CAMERA_DEVICE="$(readlink -f "$CAMERA_PATH")"

echo "Camera detected: $CAMERA_DEVICE"

exec ffmpeg \
    -hide_banner \
    -fflags nobuffer \
    -f v4l2 \
    -input_format mjpeg \
    -video_size 1280x720 \
    -framerate 15 \
    -i "$CAMERA_DEVICE" \
    -an \
    -c:v copy \
    -flush_packets 1 \
    -f mpjpeg \
    -content_type "multipart/x-mixed-replace;boundary=ffmpeg" \
    -listen 1 \
    http://0.0.0.0:8080/stream