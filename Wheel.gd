extends RigidBody2D

var motorised_body : RigidBody2D
export(float) var motor_speed = 5
export(float) var motor_power = 1e3

func _physics_process(_delta):
	if motorised_body == null: return
	var rel_vel = angular_velocity - motorised_body.angular_velocity
	var motor_rel_vel = motor_speed - rel_vel
	var impulse = motor_rel_vel * motor_power
	var clamped_impulse = clamp(impulse, -motor_power, motor_power) 
	apply_torque_impulse(clamped_impulse)
	motorised_body.apply_torque_impulse(-clamped_impulse)
