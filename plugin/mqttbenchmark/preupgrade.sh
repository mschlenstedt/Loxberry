#!/bin/bash
# Backup config before upgrade

echo "<INFO> Backing up config..."
cp -f $LBPCONFIG/mqttbenchmark.cfg /tmp/mqttbenchmark_cfg_backup 2>/dev/null
echo "<OK> Config backed up"
exit 0
