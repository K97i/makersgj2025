# Level.gd
extends Node2D

# --- EXPORTED VARIABLES (Assign these in the Godot Editor Inspector) ---

# TileMaps
@export var spanish_world_tilemap: TileMapLayer
@export var japanese_world_tilemap: TileMapLayer

# Parallax Layer Sprite Textures
@export_group("Spanish World Textures")
@export var spanish_sky_texture: Texture2D
@export var spanish_mountain_texture: Texture2D
@export var spanish_clouds_texture: Texture2D

@export_group("Japanese World Textures")
@export var japanese_sky_texture: Texture2D
@export var japanese_mountain_texture: Texture2D
@export var japanese_clouds_texture: Texture2D

# Player Reference (optional, if player is not a direct child or easily findable)
# If your player scene is always named "Player" and a direct child, you can use get_node("Player")
@export var player_node: Node # Assign your Player node here

# --- INTERNAL VARIABLES ---
enum WorldState { SPANISH, JAPANESE }
var current_world: WorldState = WorldState.SPANISH

var can_switch_world: bool = true
const SWITCH_COOLDOWN: float = 5.0 # 1 minute
var cooldown_timer: Timer

# References to Parallax Sprites (assuming Sprite2D is the child holding the texture)
# Adjust these paths if your Sprite2D nodes have different names or are nested differently
@onready var sky_sprite: Sprite2D = $Parallax/Sky/Sprite2D
@onready var mountain_sprite: Sprite2D = $Parallax/Mountain/Sprite2D
@onready var clouds_sprite: Sprite2D = $Parallax/Clouds/Sprite2D


func _ready():
	# Setup cooldown timer
	cooldown_timer = Timer.new()
	cooldown_timer.wait_time = SWITCH_COOLDOWN
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_timer_timeout)
	add_child(cooldown_timer)

	# Connect to player's signal if player_node is assigned
	if player_node and player_node.has_signal("world_switch_requested"):
		player_node.world_switch_requested.connect(attempt_world_switch)
	else:
		# Fallback if player_node isn't set or player script is different:
		# you might need to find the player differently, e.g. get_node("Player")
		# and then connect, assuming it has the signal.
		var player_in_scene = get_node_or_null("Player") # Common player name
		if player_in_scene and player_in_scene.has_signal("world_switch_requested"):
			player_in_scene.world_switch_requested.connect(attempt_world_switch)
		else:
			print_rich("[color=red]ERROR: Could not connect to Player's world_switch_requested signal.[/color]")
			print_rich("Ensure Player node is assigned or named 'Player' and has the signal.")


	# Initialize the world to the starting state
	_update_world_visuals_and_entities()
	print("Game started in Spanish World.")


func attempt_world_switch():
	if not can_switch_world:
		print("World switch is on cooldown.")
		return

	# Toggle world state
	if current_world == WorldState.SPANISH:
		current_world = WorldState.JAPANESE
		print("Switching to Japanese World...")
	else:
		current_world = WorldState.SPANISH
		print("Switching to Spanish World...")

	# Apply changes
	_update_world_visuals_and_entities()

	# Start cooldown
	can_switch_world = false
	cooldown_timer.start()
	print("World switch cooldown started:", SWITCH_COOLDOWN)


func _update_world_visuals_and_entities():
	var is_spanish_active = (current_world == WorldState.SPANISH)

	# 1. TileMaps
	# Show/hide and enable/disable collision
	if spanish_world_tilemap:
		spanish_world_tilemap.visible = is_spanish_active
		#spanish_world_tilemap.tile_set.set_collision
		#spanish_world_tilemap.tile_set.set_physics_layer_collision_layer() # Assuming world geometry is on physics layer 1
		#spanish_world_tilemap.set_collision_mask_value(1, is_spanish_active)  # Adjust if needed
		# A simpler way for TileMap physics if you don't need fine-grained layer control during switch:
		spanish_world_tilemap.collision_enabled = is_spanish_active 
	if japanese_world_tilemap:
		japanese_world_tilemap.visible = not is_spanish_active
		#japanese_world_tilemap.set_collision_layer_value(1, not is_spanish_active)
		#japanese_world_tilemap.set_collision_mask_value(1, not is_spanish_active)
		japanese_world_tilemap.collision_enabled = not is_spanish_active

	# 2. Parallax Backgrounds
	if is_spanish_active:
		if sky_sprite and spanish_sky_texture: sky_sprite.texture = spanish_sky_texture
		if mountain_sprite and spanish_mountain_texture: mountain_sprite.texture = spanish_mountain_texture
		if clouds_sprite and spanish_clouds_texture: clouds_sprite.texture = spanish_clouds_texture
	else:
		if sky_sprite and japanese_sky_texture: sky_sprite.texture = japanese_sky_texture
		if mountain_sprite and japanese_mountain_texture: mountain_sprite.texture = japanese_mountain_texture
		if clouds_sprite and japanese_clouds_texture: clouds_sprite.texture = japanese_clouds_texture
	
	# Ensure parallax sprites are valid before trying to set texture
	if not sky_sprite: print_rich("[color=yellow]Warning: Sky sprite not found. Check path: Parallax/Sky/Sprite2D[/color]")
	if not mountain_sprite: print_rich("[color=yellow]Warning: Mountain sprite not found. Check path: Parallax/Mountain/Sprite2D[/color]")
	if not clouds_sprite: print_rich("[color=yellow]Warning: Clouds sprite not found. Check path: Parallax/Clouds/Sprite2D[/color]")


	# 3. Enemies
	_set_entities_active_in_group("spanish", is_spanish_active)
	_set_entities_active_in_group("japanese", not is_spanish_active)

	# Optional: Add a small visual effect here (e.g., screen flash)
	# Example:
	var flash = ColorRect.new()
	flash.color = Color(1,1,1,0.5) # Semi-transparent white
	flash.size = get_viewport_rect().size
	add_child(flash)
	get_tree().create_timer(0.1).timeout.connect(flash.queue_free)


func _set_entities_active_in_group(group_name: String, active: bool):
	for entity in get_tree().get_nodes_in_group(group_name):
		if not entity is Node2D: # Or whatever base type your enemies are
			continue

		entity.visible = active
		
		# Toggle processing (AI, movement, etc.)
		# You might need to check which process mode they use (idle, physics, or both)
		if entity.has_method("set_process_mode"): # Godot 4.x
			entity.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
		elif entity.has_method("set_process"): # Godot 3.x fallback
			entity.set_process(active)
			entity.set_physics_process(active)

		# Toggle collision shapes
		# This assumes a common structure where the collision shape is a child.
		# Adjust "CollisionShape2D" if your enemy scenes name it differently.
		var collision_shape = entity.get_node_or_null("CollisionShape2D")
		if collision_shape and collision_shape.has_method("set_disabled"):
			collision_shape.set_disabled(not active)
		
		# IMPORTANT: If enemies need to reset their positions or state when re-activated,
		# you'd call a specific method on them here, e.g., entity.reset_state() or entity.re_activate()
		# For simplicity now, we're just toggling visibility and processing.


func _on_cooldown_timer_timeout():
	can_switch_world = true
	print("World switch cooldown finished. Ready to switch again.")
