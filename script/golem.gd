extends CharacterBody2D

class_name Golem

const speed = 50

var is_golem_chase: bool = true

var health = 250
var health_max = 250
var health_min = 0

var dead: bool = false
var taking_damage: bool = true
var damage_to_deal = 40
var is_dealing_damage: bool = false

var dir: Vector2

const gravity = 900
var knockback_force = -200
var is_roaming: bool = true

var player: CharacterBody2D
var player_in_area = false

func _process(delta):
	if !is_on_floor():
		velocity.y += gravity * delta
		velocity.x = 0
	
	if Global.playerAlive:
		is_golem_chase = true
	elif !Global.playerAlive:
		is_golem_chase = false
	
	Global.golemDamageAmount = damage_to_deal
	Global.golemDamageZone = $golemDealDamageArea
	player = Global.playerBody
	
	move(delta)
	handle_animation()
	move_and_slide()

func move(delta):
	if !dead:
		if !is_golem_chase:
			velocity += dir * speed * delta
		elif is_golem_chase and !taking_damage:
			var dir_to_player = position.direction_to(player.position) * speed
			velocity.x = dir_to_player.x
			dir.x = abs(velocity.x) / velocity.x
		elif taking_damage:
			var knockback_dir = position.direction_to(player.position) * knockback_force
			velocity.x = knockback_dir.x
		is_roaming = true
	elif dead:
		velocity.x = 0

func handle_animation():
	var anim_sprite = $AnimatedSprite2D
	if !dead and !taking_damage and !is_dealing_damage:
		anim_sprite.play("walk")
		if dir.x == -1:
			anim_sprite.flip_h = true
		elif dir.x == 1:
			anim_sprite.flip_h = false
	elif !dead and taking_damage and !is_dealing_damage:
		anim_sprite.play("hurt")
		await get_tree().create_timer(2.0)
		taking_damage = false
	elif dead and is_roaming:
		is_roaming = false
		anim_sprite.play("death")
		await get_tree().create_timer(1.0).timeout
		handle_death()
	elif !dead and is_dealing_damage:
		anim_sprite.play("deal_damage")

func handle_death():
	self.queue_free()

func _on_direction_timer_timeout():
	$DirectionTimer.wait_time = choose([1.5,2.0,2.5])
	if !is_golem_chase:
		dir = choose([Vector2.RIGHT, Vector2.LEFT])
		velocity.x = 0

func choose(array):
	array.shuffle()
	return array.front()


func _on_golem_hitbox_area_entered(area):
	var damage = Global.playerDamageAmount
	if area == Global.playerDamageZone:
		take_damage(damage)

func take_damage(damage):
	health -= damage
	taking_damage = true
	if health <= health_min:
		health = health_min
		dead = true


func _on_golem_deal_damage_area_area_entered(area):
	if area == Global.playerHitbox:
		is_dealing_damage = true
		await get_tree().create_timer(1.0).timeout
		is_dealing_damage = false
