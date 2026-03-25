#!/bin/bash
# LoxBerry Plugin postinstall -- runs as user loxberry

echo "<INFO> Creating directories..."
mkdir -p $LBPDATA/results
mkdir -p $LBPLOG

echo "<INFO> Creating default config..."
if [ ! -f $LBPCONFIG/mqttbenchmark.cfg ]; then
    cat > $LBPCONFIG/mqttbenchmark.cfg << 'EOF'
[BENCHMARK]
DURATION=60
LOGLEVEL=6
RUNS=realistic,stress
FIXES=1,2,3,4,5,6,7
EOF
    echo "<OK> Default config created"
else
    echo "<OK> Config already exists, keeping it"
fi

echo "<OK> Installation complete"
exit 0
