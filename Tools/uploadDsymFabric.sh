#!/bin/bash
# From https://docs.fabric.io/apple/crashlytics/missing-dsyms.html#bitcode-download

# Upload a DSYM for an app to Fabric/Crashlytics if it's missing.
# Usage uploadDsymFabric <Dsym>.zip

# For a production release, I had to first download the DSYM from iTunes Connect.

# I pulled this from the Info.plist
API_KEY="237a6efa41c3712c4dc41003288df88ae5178ace"

/Applications/Fabric.app/Contents/MacOS/upload-symbols -a $API_KEY -p ios $1