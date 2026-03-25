#!/bin/bash
# Restore config after upgrade

echo "<INFO> Restoring config..."
if [ -f /tmp/mqttbenchmark_cfg_backup ]; then
    cp -f /tmp/mqttbenchmark_cfg_backup $LBPCONFIG/mqttbenchmark.cfg
    rm -f /tmp/mqttbenchmark_cfg_backup
    echo "<OK> Config restored"
fi
exit 0
