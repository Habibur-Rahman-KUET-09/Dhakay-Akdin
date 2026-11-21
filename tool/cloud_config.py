#!/usr/bin/env python3
"""Writes the online backup's settings for the build (content/cloud.json):
the Firebase project id and web API key from the environment (the
repository's secrets), and the project's Google web client id, asked of
Firebase itself (or GOOGLE_WEB_CLIENT_ID if set). Prints what it found,
never the values.

    python3 tool/cloud_config.py game/content/cloud.json
"""
import json
import os
import sys
import urllib.request

out = {"project": os.environ["FIREBASE_PROJECT_ID"], "key": os.environ["FIREBASE_API_KEY"], "google_client": ""}
client = os.environ.get("GOOGLE_WEB_CLIENT_ID", "").strip()
if not client:
    try:
        url = "https://www.googleapis.com/identitytoolkit/v3/relyingparty/getProjectConfig?key=" + out["key"]
        config = json.load(urllib.request.urlopen(url, timeout=20))
        for idp in config.get("idpConfig", []):
            if idp.get("provider") == "GOOGLE" and idp.get("enabled") and idp.get("clientId"):
                client = idp["clientId"]
    except Exception as e:  # noqa: BLE001 - any failure: Google sign-in stays off
        print("::notice title=Online backup::google client id: could not ask Firebase (%s)" % type(e).__name__)
out["google_client"] = client
json.dump(out, open(sys.argv[1], "w"))
print("::notice title=Online backup::google sign-in: %s" % ("on" if client else "off (no web client id)"))
