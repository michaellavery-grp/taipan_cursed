#!/bin/bash
# Auto-detect and launch the latest version of Taipan

eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)

# Find the latest version by sorting version numbers
LATEST_VERSION=$(ls -1 Taipan_2020_v*.pl 2>/dev/null | \
    grep -v "massive_updates" | \
    sed 's/Taipan_2020_v//' | \
    sed 's/.pl$//' | \
    sort -V | \
    tail -1)

if [ -z "$LATEST_VERSION" ]; then
    echo "Error: No Taipan_2020_v*.pl files found!"
    exit 1
fi

TAIPAN_SCRIPT="Taipan_2020_v${LATEST_VERSION}.pl"

echo "Launching $TAIPAN_SCRIPT..."
perl "$TAIPAN_SCRIPT"
