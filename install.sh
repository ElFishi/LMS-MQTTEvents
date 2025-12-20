#! /bin/bash

rsync -avz --inplace \
  --chown=squeezeboxserver:nogroup \
  --exclude='install.sh' \
  --exclude='.*' \
 ./ root@lms:/var/lib/squeezeboxserver/Plugins/MQTTEvents/

