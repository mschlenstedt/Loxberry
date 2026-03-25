#!/bin/bash
# LoxBerry Plugin postroot -- runs as root

echo "<INFO> Setting script permissions..."
chmod +x $LBPBIN/mqtt-benchmark.sh
chmod +x $LBPBIN/mqtt-loadgen.pl
chmod +x $LBPBIN/mqtt-metric-collector.pl
chmod +x $LBPBIN/mqttgateway_benchmarkable.pl
echo "<OK> Permissions set"
exit 0
