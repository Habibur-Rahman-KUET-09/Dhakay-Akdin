## The save's copy online (Firebase, over its plain HTTPS APIs, so no
## Android plugin is needed). On first use an account with no name is
## made quietly; after each day the save is copied to Firestore at
## players/<account>. To move to another phone the player can tie the
## account to their Google account (Android's own picker, through the
## GoogleSignIn plugin in addons/) or to an email and password, and sign
## in the same way there.
## The project's id and web API key come from content/cloud.json, which
## the build writes from the repository's secrets; without it all of this
## is off and the game plays as before.
extends Node

const CONFIG := "res://content/cloud.json"
const AUTH := "user://cloud.cfg"
const AUTH_URL := "https://identitytoolkit.googleapis.com/v1/accounts:"
const TOKEN_URL := "https://securetoken.googleapis.com/v1/token?key="

signal _google_done(token: String, error: String)

var project := ""
var key := ""
## The Firebase project's web client, for Google sign-in ("" if unknown).
var google_client := ""
var uid := ""
var email := ""
## How the account is tied: "" (nameless), "google" or "password".
var provider := ""
var _refresh := ""
var _token := ""
var _token_until := 0.0
## The last copy made: the save's day and the time ("" if never).
var last_day := -1
var last_time := ""


func _init() -> void:
	if FileAccess.file_exists(CONFIG):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
		if typeof(parsed) == TYPE_DICTIONARY:
			project = str(parsed.get("project", ""))
			key = str(parsed.get("key", ""))
			google_client = str(parsed.get("google_client", ""))
	var c := ConfigFile.new()
	if c.load(AUTH) == OK:
		uid = c.get_value("auth", "uid", "")
		email = c.get_value("auth", "email", "")
		provider = c.get_value("auth", "provider", "")
		_refresh = c.get_value("auth", "refresh", "")
		last_day = c.get_value("copy", "day", -1)
		last_time = c.get_value("copy", "time", "")


## Copies a save online from anywhere (a scene at the end of its day),
## without waiting for it.
static func backup(parent: Node, data: Dictionary) -> void:
	var cloud = load("res://scripts/ui/cloud.gd").new()
	if not cloud.enabled():
		cloud.free()
		return
	parent.add_child(cloud)
	cloud._copy_all(data)


## The save, then the public card (leaderboards, friends).
func _copy_all(data: Dictionary) -> void:
	await upload(data)
	# The public card: the leaderboards' numbers, and the friends' part.
	var board = load("res://scripts/rules/leaderboard.gd")
	await publish_card(board.card(data, Time.get_date_string_from_system()))


func enabled() -> bool:
	return project != "" and key != ""


func _remember() -> void:
	var c := ConfigFile.new()
	c.set_value("auth", "uid", uid)
	c.set_value("auth", "email", email)
	c.set_value("auth", "provider", provider)
	c.set_value("auth", "refresh", _refresh)
	c.set_value("copy", "day", last_day)
	c.set_value("copy", "time", last_time)
	c.save(AUTH)


# --- HTTPS ---------------------------------------------------------------------


## One request: {ok, code, data} (data parsed from JSON, or {}).
func _call(url: String, method: int, body := "", headers: PackedStringArray = PackedStringArray()) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 15.0
	# In a browser the reply comes already unzipped while still marked as
	# gzip: unzipping it again spoils it (sign-in failed as UNKNOWN on the
	# web build). Let the browser handle compression there.
	if OS.has_feature("web"):
		http.accept_gzip = false
	add_child(http)
	var err := http.request(url, headers, method, body)
	if err != OK:
		http.queue_free()
		return {"ok": false, "code": 0, "data": {}}
	var result: Array = await http.request_completed
	http.queue_free()
	var code: int = result[1]
	var text: String = (result[3] as PackedByteArray).get_string_from_utf8()
	var data = JSON.parse_string(text) if text != "" else {}
	# A list (Firestore's batchGet) is kept under "list".
	if typeof(data) == TYPE_ARRAY:
		data = {"list": data}
	elif typeof(data) != TYPE_DICTIONARY:
		data = {}
	return {"ok": result[0] == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300, "code": code, "data": data}


func _json_post(url: String, body: Dictionary) -> Dictionary:
	return await _call(url, HTTPClient.METHOD_POST, JSON.stringify(body), PackedStringArray(["Content-Type: application/json"]))


## Firebase's error name from a failed reply ("EMAIL_EXISTS"…), or
## "NETWORK" when there was no reply at all.
static func error_of(reply: Dictionary) -> String:
	if int(reply.get("code", 0)) == 0:
		return "NETWORK"
	var e = reply.get("data", {}).get("error", {})
	if typeof(e) != TYPE_DICTIONARY or e.is_empty():
		# A reply without Firebase's error: say which, for a report.
		return "HTTP_%d" % int(reply.code)
	# Firestore says what went wrong in "status" (PERMISSION_DENIED…); the
	# sign-in service in the first word of "message" (EMAIL_EXISTS…).
	if str(e.get("status", "")) != "":
		return str(e.status)
	return str(e.get("message", "UNKNOWN")).split(" ")[0].split(":")[0]


func _took(data: Dictionary) -> void:
	_token = str(data.get("idToken", data.get("id_token", "")))
	_refresh = str(data.get("refreshToken", data.get("refresh_token", _refresh)))
	uid = str(data.get("localId", data.get("user_id", uid)))
	_token_until = Time.get_unix_time_from_system() + float(data.get("expiresIn", data.get("expires_in", "3600"))) - 60.0
	_remember()


## A fresh token for the account, making a nameless account the first
## time. "" when it worked, else the error.
func ensure_user() -> String:
	if not enabled():
		return "OFF"
	if _token != "" and Time.get_unix_time_from_system() < _token_until:
		return ""
	if _refresh != "":
		var reply := await _call(TOKEN_URL + key, HTTPClient.METHOD_POST,
			"grant_type=refresh_token&refresh_token=" + _refresh.uri_encode(),
			PackedStringArray(["Content-Type: application/x-www-form-urlencoded"]))
		if reply.ok:
			_took(reply.data)
			return ""
		if error_of(reply) == "NETWORK":
			return "NETWORK"
	var made := await _json_post(AUTH_URL + "signUp?key=" + key, {"returnSecureToken": true})
	if not made.ok:
		return error_of(made)
	email = ""
	_took(made.data)
	return ""


# --- The copy of the save ------------------------------------------------------


func _doc_url(id: String) -> String:
	return "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/players/%s" % [project, id]


## The save as Firestore fields: the whole save as text, its day, when.
static func to_fields(data: Dictionary, when: String) -> Dictionary:
	return {"fields": {
		"save": {"stringValue": JSON.stringify(data)},
		"day": {"integerValue": str(int(data.get("day", 0)))},
		"updated": {"stringValue": when},
	}}


## A Firestore document back to {save, day, updated}; {} if it is not one.
static func from_doc(doc: Dictionary) -> Dictionary:
	var f = doc.get("fields", {})
	if typeof(f) != TYPE_DICTIONARY or not f.has("save"):
		return {}
	var save = JSON.parse_string(str(f.save.get("stringValue", "")))
	if typeof(save) != TYPE_DICTIONARY:
		return {}
	return {"save": save, "day": int(f.get("day", {}).get("integerValue", "0")), "updated": str(f.get("updated", {}).get("stringValue", ""))}


## Copies the save online. "" when it worked, else the error.
func upload(data: Dictionary) -> String:
	var e := await ensure_user()
	if e != "":
		return e
	var when := Time.get_datetime_string_from_system(false, true)
	var reply := await _call(_doc_url(uid), HTTPClient.METHOD_PATCH, JSON.stringify(to_fields(data, when)),
		PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + _token]))
	if not reply.ok:
		return error_of(reply)
	last_day = int(data.get("day", 0))
	last_time = when
	_remember()
	return ""


## The copy online for this account: {save, day, updated}, or {} if none
## (or no network).
func download() -> Dictionary:
	if await ensure_user() != "":
		return {}
	var reply := await _call(_doc_url(uid), HTTPClient.METHOD_GET, "",
		PackedStringArray(["Authorization: Bearer " + _token]))
	return from_doc(reply.data) if reply.ok else {}


# --- Friends (friends.gd): codes, cards, gifts -------------------------------------


func _docs() -> String:
	return "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % project


func _auth() -> PackedStringArray:
	return PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + _token])


## A plain value as a Firestore value (text, whole numbers, numbers,
## yes/no, lists, dictionaries).
static func to_value(v) -> Dictionary:
	match typeof(v):
		TYPE_BOOL:
			return {"booleanValue": v}
		TYPE_INT:
			return {"integerValue": str(v)}
		TYPE_FLOAT:
			return {"doubleValue": v}
		TYPE_DICTIONARY:
			var fields := {}
			for k in v:
				fields[str(k)] = to_value(v[k])
			return {"mapValue": {"fields": fields}}
		TYPE_ARRAY:
			var values := []
			for x in v:
				values.append(to_value(x))
			return {"arrayValue": {"values": values}}
		TYPE_NIL:
			return {"nullValue": null}
	return {"stringValue": str(v)}


## A Firestore value back to a plain one.
static func from_value(v):
	if typeof(v) != TYPE_DICTIONARY:
		return null
	if v.has("stringValue"):
		return str(v.stringValue)
	if v.has("integerValue"):
		return int(v.integerValue)
	if v.has("doubleValue"):
		return float(v.doubleValue)
	if v.has("booleanValue"):
		return bool(v.booleanValue)
	if v.has("mapValue"):
		return from_fields(v.mapValue.get("fields", {}))
	if v.has("arrayValue"):
		var out := []
		for x in v.arrayValue.get("values", []):
			out.append(from_value(x))
		return out
	return null


static func to_fields_of(data: Dictionary) -> Dictionary:
	return to_value(data).mapValue


static func from_fields(fields) -> Dictionary:
	var out := {}
	if typeof(fields) == TYPE_DICTIONARY:
		for k in fields:
			out[k] = from_value(fields[k])
	return out


## Claims a friend code for this account. "" when it is ours now,
## "ALREADY_EXISTS" when someone has it, else the error.
func claim_code(code: String) -> String:
	var e := await ensure_user()
	if e != "":
		return e
	var reply := await _call(_docs() + "/codes?documentId=" + code.uri_encode(), HTTPClient.METHOD_POST,
		JSON.stringify(to_fields_of({"uid": uid})), _auth())
	return "" if reply.ok else error_of(reply)


## The account behind a friend code; "" if none (or no network).
func find_code(code: String) -> String:
	if await ensure_user() != "":
		return ""
	var reply := await _call(_docs() + "/codes/" + code.uri_encode(), HTTPClient.METHOD_GET, "", _auth())
	if not reply.ok:
		return ""
	return str(from_fields(reply.data.get("fields", {})).get("uid", ""))


## Writes this player's card for friends to see. "" or the error.
func publish_card(c: Dictionary) -> String:
	var e := await ensure_user()
	if e != "":
		return e
	var body := c.duplicate()
	body["updated"] = Time.get_datetime_string_from_system(true, true)
	var reply := await _call(_docs() + "/profiles/" + uid, HTTPClient.METHOD_PATCH, JSON.stringify(to_fields_of(body)), _auth())
	return "" if reply.ok else error_of(reply)


## Friends' cards, by account ({} for none or no network).
func cards(uids: Array) -> Dictionary:
	var out := {}
	if uids.is_empty() or await ensure_user() != "":
		return out
	var names := []
	for u in uids:
		names.append("projects/%s/databases/(default)/documents/profiles/%s" % [project, u])
	var reply := await _call(_docs() + ":batchGet", HTTPClient.METHOD_POST, JSON.stringify({"documents": names}), _auth())
	if not reply.ok:
		return out
	for r in reply.data.get("list", []):
		if typeof(r) == TYPE_DICTIONARY and r.has("found"):
			out[str(r.found.name).get_file()] = from_fields(r.found.get("fields", {}))
	return out


## Sends a gift or sticker (friends.gd's send) to a friend. "" or the error.
func send_item(to_uid: String, item: Dictionary) -> String:
	var e := await ensure_user()
	if e != "":
		return e
	var reply := await _call(_docs() + "/inbox/%s/items" % to_uid, HTTPClient.METHOD_POST, JSON.stringify(to_fields_of(item)), _auth())
	return "" if reply.ok else error_of(reply)


## What came in, taken off the server: [{from, name, kind, sticker, date}].
func take_inbox() -> Array:
	var out := []
	if await ensure_user() != "":
		return out
	var reply := await _call(_docs() + "/inbox/%s/items?pageSize=50" % uid, HTTPClient.METHOD_GET, "", _auth())
	if not reply.ok:
		return out
	for d in reply.data.get("documents", []):
		out.append(from_fields(d.get("fields", {})))
		await _call("https://firestore.googleapis.com/v1/" + str(d.name), HTTPClient.METHOD_DELETE, "", _auth())
	return out


## A leaderboard: the top `n` cards by a field, highest first:
## [{uid, name, value}] ([] for none or no network).
func top(field: String, n: int) -> Array:
	var out := []
	if await ensure_user() != "":
		return out
	var q := {"structuredQuery": {"from": [{"collectionId": "profiles"}],
		"orderBy": [{"field": {"fieldPath": field}, "direction": "DESCENDING"}], "limit": n}}
	var reply := await _call(_docs() + ":runQuery", HTTPClient.METHOD_POST, JSON.stringify(q), _auth())
	if not reply.ok:
		return out
	for r in reply.data.get("list", []):
		if typeof(r) == TYPE_DICTIONARY and r.has("document"):
			var f := from_fields(r.document.get("fields", {}))
			out.append({"uid": str(r.document.name).get_file(), "name": str(f.get("name", "")), "value": int(f.get(field, 0))})
	return out


## Where a number stands in a leaderboard: 1 + how many are higher
## (0 when it cannot be told).
func rank_of(field: String, value: int) -> int:
	if value <= 0 or await ensure_user() != "":
		return 0
	var q := {"structuredAggregationQuery": {
		"structuredQuery": {"from": [{"collectionId": "profiles"}],
			"where": {"fieldFilter": {"field": {"fieldPath": field}, "op": "GREATER_THAN", "value": {"integerValue": str(value)}}}},
		"aggregations": [{"alias": "n", "count": {}}]}}
	var reply := await _call(_docs() + ":runAggregationQuery", HTTPClient.METHOD_POST, JSON.stringify(q), _auth())
	if not reply.ok:
		return 0
	for r in reply.data.get("list", []):
		if typeof(r) == TYPE_DICTIONARY and r.has("result"):
			return 1 + int(from_value(r.result.get("aggregateFields", {}).get("n", {})))
	return 0


## Lets go of the card and the code (when the account is deleted).
func drop_friends(code: String) -> void:
	await _call(_docs() + "/profiles/" + uid, HTTPClient.METHOD_DELETE, "", _auth())
	if code != "":
		await _call(_docs() + "/codes/" + code.uri_encode(), HTTPClient.METHOD_DELETE, "", _auth())


# --- Email and password, to move phones ------------------------------------------


## Ties this phone's account (and its copy online) to an email and
## password. "" when it worked, else the error.
func link_email(address: String, password: String) -> String:
	var e := await ensure_user()
	if e != "":
		return e
	var reply := await _json_post(AUTH_URL + "update?key=" + key,
		{"idToken": _token, "email": address, "password": password, "returnSecureToken": true})
	if not reply.ok:
		return error_of(reply)
	email = address
	provider = "password"
	_took(reply.data)
	return ""


## Signs in with an email and password (on a new phone). "" when it
## worked, else the error. The copy online can then be downloaded.
func sign_in(address: String, password: String) -> String:
	if not enabled():
		return "OFF"
	var reply := await _json_post(AUTH_URL + "signInWithPassword?key=" + key,
		{"email": address, "password": password, "returnSecureToken": true})
	if not reply.ok:
		return error_of(reply)
	email = address
	provider = "password"
	_took(reply.data)
	return ""


# --- Google --------------------------------------------------------------------


## Google sign-in works here: on Android with the plugin, and the
## project's web client known.
func google_ready() -> bool:
	if not enabled() or google_client == "":
		return false
	return OS.has_feature("web") or Engine.has_singleton("GoogleSignIn")


## In a browser, Google's sign-in script, loaded ahead so the popup can open
## straight from the tap (browsers block popups opened long after one).
const WEB_GOOGLE_JS := """
window.pdGooglePreload = function () {
  if (window.google && google.accounts && google.accounts.oauth2) return;
  if (document.getElementById('pd-gsi')) return;
  var s = document.createElement('script');
  s.id = 'pd-gsi'; s.src = 'https://accounts.google.com/gsi/client'; s.async = true;
  document.head.appendChild(s);
};
window.pdGoogleSignIn = function (clientId, done) {
  function go() {
    try {
      var c = google.accounts.oauth2.initTokenClient({
        client_id: clientId, scope: 'openid email profile',
        callback: function (r) { done(r && r.access_token ? 'OK:' + r.access_token : 'ERR:' + ((r && r.error) || 'no_token')); },
        error_callback: function (e) { done('ERR:' + ((e && e.type) || 'popup')); }
      });
      c.requestAccessToken();
    } catch (e) { done('ERR:' + e); }
  }
  if (window.google && google.accounts && google.accounts.oauth2) { go(); return; }
  window.pdGooglePreload();
  var s = document.getElementById('pd-gsi');
  s.addEventListener('load', go);
  s.addEventListener('error', function () { done('ERR:load'); });
};
"""

## The browser's answer comes back through this (kept until the next try,
## not freed while it runs).
var _web_back = null


func web_google_preload() -> void:
	if not OS.has_feature("web") or not google_ready():
		return
	JavaScriptBridge.eval(WEB_GOOGLE_JS, true)
	JavaScriptBridge.eval("window.pdGooglePreload()", true)


func _web_google_said(args: Array) -> void:
	var said := str(args[0]) if args.size() > 0 else "ERR:none"
	if said.begins_with("OK:"):
		_google_done.emit(said.substr(3), "")
	else:
		_google_done.emit("", said.substr(4))


## Shows Android's Google account picker; then, with `link`, ties this
## phone's account to the Google account chosen, or else signs in as
## whoever that Google account already is (on a new phone). "" when it
## worked, else the error ("CANCELLED" if the picker was closed).
func google(link: bool) -> String:
	if not google_ready():
		return "NO_GOOGLE"
	var web := OS.has_feature("web")
	if web:
		# Google's popup in the browser gives an access token for the account.
		web_google_preload()
		_web_back = JavaScriptBridge.create_callback(_web_google_said)
		# Untyped, so the page's own function can be called on it.
		var page = JavaScriptBridge.get_interface("window")
		page.pdGoogleSignIn(google_client, _web_back)
	else:
		var plugin = Engine.get_singleton("GoogleSignIn")
		# Plugin signals are connected by name (as Godot's Android plugin docs do).
		if not plugin.is_connected("signed_in", _google_ok):
			plugin.connect("signed_in", _google_ok)
			plugin.connect("sign_in_failed", _google_fail)
		plugin.signIn(google_client)
	var got: Array = await _google_done
	if got[1] != "":
		var why := str(got[1]).split(" ")[0]
		return "CANCELLED" if why in ["popup_closed", "access_denied"] else why
	var credential := ("access_token=%s" if web else "id_token=%s") % got[0]
	var body := {"requestUri": "http://localhost", "postBody": credential + "&providerId=google.com",
		"returnSecureToken": true, "returnIdpCredential": true}
	if link:
		var e := await ensure_user()
		if e != "":
			return e
		body["idToken"] = _token
	var reply := await _json_post(AUTH_URL + "signInWithIdp?key=" + key, body)
	if not reply.ok:
		return error_of(reply)
	email = str(reply.data.get("email", ""))
	provider = "google"
	_took(reply.data)
	return ""


func _google_ok(token: String) -> void:
	_google_done.emit(token, "")


func _google_fail(reason: String) -> void:
	_google_done.emit("", reason)


## Removes this account and its copy (used by the build's own check).
func delete_account(code_to_drop := "") -> String:
	if await ensure_user() != "":
		return "NETWORK"
	await _call(_doc_url(uid), HTTPClient.METHOD_DELETE, "", PackedStringArray(["Authorization: Bearer " + _token]))
	await drop_friends(code_to_drop)
	var reply := await _json_post(AUTH_URL + "delete?key=" + key, {"idToken": _token})
	return "" if reply.ok else error_of(reply)
