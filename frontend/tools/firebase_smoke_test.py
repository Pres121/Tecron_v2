#!/usr/bin/env python3
import json
import urllib.request
import urllib.error
import datetime
import sys

# Config (from lib/firebase_options.dart web values)
API_KEY = "AIzaSyCmxZtf5o2X70TIIUtuFl5lxBEU8wi3WBI"
PROJECT_ID = "tecron-v1"

EMAIL = f"copilot-smoke-{int(datetime.datetime.utcnow().timestamp())}@example.com"
PASSWORD = "Test1234"

def post(url, data, headers=None):
    hdrs = {"Content-Type": "application/json"}
    if headers:
        hdrs.update(headers)
    req = urllib.request.Request(url, data=json.dumps(data).encode(), headers=hdrs, method="POST")
    try:
        with urllib.request.urlopen(req) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        try:
            return {"error": json.loads(body)}
        except Exception:
            return {"error": body}

def get(url, headers=None):
    hdrs = {}
    if headers:
        hdrs.update(headers)
    req = urllib.request.Request(url, headers=hdrs)
    try:
        with urllib.request.urlopen(req) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        try:
            return {"error": json.loads(body)}
        except Exception:
            return {"error": body}

def main():
    print("Starting Firebase REST smoke test")

    signin_url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={API_KEY}"
    signup_url = f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={API_KEY}"

    print("Attempting sign-in (may fail if account doesn't exist)")
    r = post(signin_url, {"email": EMAIL, "password": PASSWORD, "returnSecureToken": True})
    if "error" in r:
        print("Sign-in failed, attempting sign-up:", r["error"])  # expected on first run
        r = post(signup_url, {"email": EMAIL, "password": PASSWORD, "returnSecureToken": True})
        if "error" in r:
            print("Sign-up failed:", r["error"])
            sys.exit(2)

    print("Auth success")
    # Extract tokens
    id_token = r.get("idToken")
    local_id = r.get("localId")
    print("UID:", local_id)

    # Write a Firestore document under users/{uid}/predictions
    doc_url = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/users/{local_id}/predictions"
    now = datetime.datetime.utcnow().isoformat() + "Z"
    doc = {
        "fields": {
            "brand": {"stringValue": "SmokeTestBrand"},
            "model": {"stringValue": "SmokeModel"},
            "charging_watt": {"doubleValue": 12.34},
            "source": {"stringValue": "SmokeTest"},
            "created_at": {"timestampValue": now},
        }
    }
    headers = {"Authorization": "Bearer " + id_token}
    print("Writing a test document to Firestore...")
    w = post(doc_url, doc, headers)
    if "error" in w:
        print("Write failed:", w["error"])
        sys.exit(3)
    print("Write response:", json.dumps(w, indent=2))

    # Read back the collection
    list_url = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/users/{local_id}/predictions"
    print("Listing documents in the predictions collection...")
    l = get(list_url, headers)
    if "error" in l:
        print("List failed:", l["error"])
        sys.exit(4)
    print("List response keys:", list(l.keys()))
    print(json.dumps(l, indent=2))
    print("Smoke test finished successfully. Test account:", EMAIL)

if __name__ == '__main__':
    main()
