#!/bin/sh -ex

set -ex

sed -i '/STREAM_URL/d' /etc/nixdvr.d/camera.cfg
echo "STREAM_URL=$STREAM_URL" >> /etc/nixdvr.d/camera.cfg

sed -i '/STREAM_NAME/d' /etc/nixdvr.d/camera.cfg
echo "STREAM_NAME=$STREAM_NAME" >> /etc/nixdvr.d/camera.cfg

sed -i '/DEBUG_LEVEL/d' /etc/nixdvr.d/camera.cfg
echo "DEBUG_LEVEL=$DEBUG_LEVEL" >> /etc/nixdvr.d/camera.cfg

cat /etc/nixdvr.d/camera.cfg

exec supervisord -c /etc/supervisor/supervisord.conf
