extends Area2D
class_name EnemyProjectile

var speed: float = 250.0
var direction: Vector2 = Vector2.RIGHT
var damage: int = 15
var lifetime: float = 4.0
var has_hit: bool = false
var knockback_force: float = 150.0

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Create a simple visual if no sprite exists
	if not sprite:
		sprite = Sprite2D.new()
		sprite.texture = _create_simple_texture()
		sprite.modulate = Color.RED
		add_child(sprite)
	
	# Auto-destroy after lifetime
	await get_tree().create_timer(lifetime).timeout
	if not has_hit:
		queue_free()

func _create_simple_texture() -> ImageTexture:
	# Create a simple circle texture
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	
	# Draw a red circle
	for x in range(16):
		for y in range(16):
			var dist = Vector2(x - 8, y - 8).length()
			if dist < 6:
				img.set_pixel(x, y, Color.RED)
	
	return ImageTexture.create_from_image(img)

func set_direction(dir: Vector2, dmg: int) -> void:
	direction = dir.normalized()
	damage = dmg
	
	# Rotate sprite to face direction
	if sprite:
		rotation = direction.angle()
	
	print("[Projectile] Created with damage: ", damage, " direction: ", direction)

func _physics_process(delta: float) -> void:
	if not has_hit:
		position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if has_hit:
		return
	
	print("[Projectile] Hit body: ", body.name)
	
	if body is Player:
		if body.has_method("take_damage"):
			body.take_damage(damage)
			print("[Projectile] Dealt ", damage, " damage to player")
		
		# Apply knockback
		if body.has_method("apply_knockback"):
			body.apply_knockback(direction * knockback_force)
		
		has_hit = true
		queue_free()
	elif body is TileMap or body.is_in_group("walls") or body.is_in_group("ground"):
		print("[Projectile] Hit terrain, destroying")
		has_hit = true
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if has_hit:
		return
	
	print("[Projectile] Hit area: ", area.name)
	
	if area == Global.playerHitbox:
		var player = Global.playerBody
		if player and player.has_method("take_damage"):
			player.take_damage(damage)
			print("[Projectile] Dealt ", damage, " damage to player via hitbox")
		
		# Apply knockback
		if player and player.has_method("apply_knockback"):
			player.apply_knockback(direction * knockback_force)
		
		has_hit = true
		#queue_free().take_damage(damage)
		print("[Projectile] Dealt ", damage, " damage to player via hitbox")
		has_hit = true
		queue_free()
