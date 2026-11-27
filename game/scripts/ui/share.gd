## Sharing what the game made, a picture or a video: the phone's share
## sheet (the Android plugin), the browser's on the web, else false (the
## caller falls back to WhatsApp with the text).
extends RefCounted

const DIR := "user://share"


static func plugin() -> Object:
	return Engine.get_singleton("GoogleSignIn") if Engine.has_singleton("GoogleSignIn") else null


## Whether this build can make a video (the Android app, whose plugin has
## makeVideo). has_method() cannot see a Java plugin's methods (it was
## always false on the phone, so the reel button never showed).
static func can_video() -> bool:
	return plugin() != null and OS.get_name() == "Android"


## Saves `img` under share/ and opens the share sheet with it. True if it
## could be offered.
static func image(img: Image, name: String, text: String) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := DIR.path_join(name + ".png")
	img.save_png(path)
	var p := plugin()
	if p != null:
		p.shareImage(ProjectSettings.globalize_path(path), text)
		return true
	if OS.has_feature("web"):
		var b64 := Marshalls.raw_to_base64(img.save_png_to_buffer())
		var js := ("(function(){try{var b=atob(%s),a=new Uint8Array(b.length);for(var i=0;i<b.length;i++)a[i]=b.charCodeAt(i);"
			+ "var f=new File([a],%s,{type:'image/png'});"
			+ "if(navigator.canShare&&navigator.canShare({files:[f]})){navigator.share({files:[f],text:%s});return true}"
			+ "var u=URL.createObjectURL(f),l=document.createElement('a');l.href=u;l.download=%s;"
			+ "document.body.appendChild(l);l.click();l.remove();return true}catch(e){return false}})()") % [
				JSON.stringify(b64), JSON.stringify(name + ".png"), JSON.stringify(text), JSON.stringify(name + ".png")]
		return bool(JavaScriptBridge.eval(js, true))
	return false


## The share sheet with a video already under share/.
static func video(path: String, text: String) -> bool:
	var p := plugin()
	if not can_video():
		return false
	p.shareVideo(ProjectSettings.globalize_path(path), text)
	return true
