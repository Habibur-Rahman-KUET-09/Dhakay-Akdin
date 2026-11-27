## Draws a Control tree off screen into a picture (for stickers and photo
## frames): a SubViewport of the given size, one frame, its image.
extends RefCounted


## Returns the picture of `content` drawn at `size` (transparent where
## nothing is drawn, when `clear`). `host` is any node in the tree.
static func picture(host: Node, content: Control, size: Vector2i, clear := false) -> Image:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = clear
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.add_child(content)
	host.add_child(vp)
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img
