#!/bin/bash
# From https://docs.fabric.io/apple/crashlytics/missing-dsyms.html#bitcode-download

# Upload a DSYM for an app to Fabric/Crashlytics if it's missing.
# Usage uploadDsymFabric <Dsym>.zip

# For a production release, I had to first download the DSYM from iTunes Connect.

# I pulled this from the Info.plist
API_KEY="237a6efa41c3712c4dc41003288df88ae5178ace"

# Note: I got warning: skipping Apple dSYM: /var/folders/50/3pr8rsks0zqfs1j53_k0l0nh0000gp/T///Users/chris/Desktop/dSYMs.zip.unzipped/C018F2DF-17EF-3DC8-AC79-82DED0DD6536.dSYM
# seemingly when I tried to download the dSYM's from Apple iTunes Connect too early. E.g., just after processing completed. I got an archive with an odd extension, e.g., .dsym

/Applications/Fabric.app/Contents/MacOS/upload-symbols -a $API_KEY -p ios $1
