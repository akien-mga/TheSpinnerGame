extends Node

var HTTP = HTTPClient.new()
var prt = 80
var is_saving = 0
var game_scene = preload("res://scenes/game.tscn")
var game_instance
var menu_scene = preload("res://scenes/hex_menu.tscn")
var menu_instance
var hex_slide_scene = preload("res://scripts/hex_slider.gd")
var hex_slide_instance
var device_ID = Vector2(0,0)
var file = File.new()
var in_lab = 1
var twn = Tween.new()
var compliments = PoolStringArray(["MONOMENTAL","DUOLICIOUS","TRIUMPHANT","TETRIFIC","PENTASTIC","HEXQUISITE"])

func _ready():
	randomize()
	if !file.file_exists("user://deviceID"):
		file.open_compressed("user://deviceID",File.WRITE)
		device_ID = Vector2(OS.get_unix_time(),randi())
		file.store_32(device_ID.x)
		file.store_32(device_ID.y)
		file.close()
	else:
		file.open_compressed("user://deviceID",File.READ)
		device_ID.x = int(file.get_32())
		device_ID.y = int(file.get_32())
		file.close()
	if file.file_exists("user://hiscores"):
		file.open_compressed("user://hiscores",File.READ)
		for i in range(global.hi_scores.size()):
			global.hi_scores[i] = int(file.get_32())
		file.close()
	if in_lab:
		global.fail_thresh = 9*2
		add_child(load("res://scripts/eye_calib.gd").new())
	else:
		global.fail_thresh = 9*(fmod(device_ID.y,4)+1)
	for i in range(6):
		for j in range(2):
			hex_slide_instance = hex_slide_scene.new()
			add_child(hex_slide_instance)
			hex_slide_instance.create(i,j)
	new_menu()
	add_child(twn)

func new_menu():
	menu_instance = menu_scene.instance()
	add_child(menu_instance)

func start_level(lobe):
	is_saving = 0
	if lobe == 6:
		global.fail_thresh = 9
	game_instance = game_scene.instance()
	global.init(lobe,device_ID)
	add_child(game_instance)
	menu_instance.queue_free()

func save_data(win):
	if !is_saving:
		is_saving = 1
		var file = File.new()
		file.open(global.save_file_name, file.WRITE)
		file.store_line(to_json(global.data))
		file.close()
		# SEND TO SERVER
		var url = "/post.php"
		var error = 0
		error = HTTP.connect_to_host("199.247.17.106", prt)
		assert(error == OK)

		while HTTP.get_status() == HTTPClient.STATUS_CONNECTING or HTTP.get_status() == HTTPClient.STATUS_RESOLVING:
			HTTP.poll()
			print(HTTP.get_status())
			OS.delay_msec(50)
		assert(HTTP.get_status() == HTTPClient.STATUS_CONNECTED)

		#var QUERY = HTTP.query_string_from_dict(global.data)
		var QUERY = to_json(global.data)
		var HEADERS = ["Content-Type: application/json"]

		HTTP.request(HTTPClient.METHOD_POST, url, HEADERS, QUERY)

		while HTTP.get_status() == HTTPClient.STATUS_REQUESTING:
			HTTP.poll()
			print(HTTP.get_status())
			OS.delay_msec(50)

		#update high scores
		if global.score > global.hi_scores[global.curr_wv-1]:
			global.hi_scores[global.curr_wv-1] = global.score
		file.open_compressed("user://hiscores",File.WRITE)
		for i in range(global.hi_scores.size()):
			file.store_32((global.hi_scores[i]))
		file.close()
		end_seq(win)
		#menu_instance = menu_scene.instance()
		#add_child(menu_instance)
		game_instance.queue_free()
		#is_saving = 0
		
func end_seq(win):
	get_tree().call_group("hex_slider","hide")
	var lbl = Label.new()
	lbl.valign = Label.VALIGN_CENTER
	lbl.align = Label.ALIGN_CENTER
	lbl.rect_size = Vector2(global.w,global.h)
	lbl.rect_position = Vector2(0,0)#Vector2(global.w,global.h)/2 - lbl.rect_size/2
	lbl.set("custom_fonts/font",global.fnt)
	twn.start()
	if win:	
		lbl.set("custom_colors/font_color",global.hex_color(6,1))
		lbl.text = "YOU ARE\n" + compliments[global.curr_wv-1] + "!"
		if global.curr_wv < 6:# and !global.is_unlocked(global.curr_wv):
			lbl.text += "\nLEVEL " + str(global.curr_wv+1) + " UNLOCKED."
#		timed_play(game_instance.get_node("Spawner").notesB,game_instance.get_node("Spawner").notesT,2)#game_instance.get_node("progress_tween").play_state.z-1)#PLAY MUSIC
	else:
		lbl.set("custom_colors/font_color",global.hint_color(7))
		lbl.text = "YOU GOT\nHEXXED!"
		twn.interpolate_callback($lose,global.move_time_new,"play")
	twn.interpolate_property(global.fnt,"size",1,80,global.move_time_new,Tween.TRANS_SINE,Tween.EASE_IN_OUT)
	add_child(lbl)
	twn.interpolate_callback(self,global.move_time_new*12,"restart_menu")
	twn.interpolate_callback(lbl,global.move_time_new*12,"queue_free")
#	twn.interpolate_callback(twn,global.move_time_new*12,"stop")

func restart_menu():
	menu_instance = menu_scene.instance()
	add_child(menu_instance)
#
#func drone_timer(counter,indT,indB):
#	if counter == 0:
#		global.data["drone_play"].push_back(OS.get_ticks_msec())
#	if $"../Spawner".notesT[indT].y == counter:
#		AudioServer.get_bus_effect(4,0).pitch_scale = pow(2,$"../Spawner".notesT[indT].x/12.0-5-1)
#		$"../drone".play()
#		indT += 1
#	if $"../Spawner".notesB[indB].y == counter:
#		AudioServer.get_bus_effect(6,0).pitch_scale = pow(2,$"../Spawner".notesB[indB].x/12.0-5-1)
#		$"../droneB".play()
#		indB += 1
#	counter += 1
#	if counter >= play_state.z*global.measure_time:
#		indT = 0
#		indB = 0
#		twn.interpolate_callback(self,global.move_time_new + 12*global.move_time_new,"drone_timer",0,indT,indB)
#	else:
#		twn.interpolate_callback(self,global.move_time_new,"drone_timer",counter,indT,indB)
	
#func timed_play(notesB,notesT,num_measures):
#	var play_state = Vector3(0,0,num_measures)
#	var start_time
#	while play_state.x < notesB.size() and notesB[play_state.x].y < (play_state.z+1)*global.measure_time:
#		start_time = (notesB[play_state.x].y)/global.measure_time*global.game_measure
#		twn.interpolate_callback(self,start_time,"play_timed_midiB",notesB[play_state.x].x)
#		play_state.x += 1
#	while play_state.y < notesT.size() and notesT[play_state.y].y < (play_state.z+1)*global.measure_time:
#		start_time = (notesT[play_state.y].y)/global.measure_time*global.game_measure
#		twn.interpolate_callback(self,start_time,"play_timed_midi",notesT[play_state.y].x)
#		play_state.y += 1
#	#play_state.z += 1
#	#
#
#func play_timed_midi(pitch):
#	AudioServer.get_bus_effect(1,0).pitch_scale = pow(2,pitch/12.0-5-1)
#	$spiccato.play()
#
#func play_timed_midiB(pitch):
#	AudioServer.get_bus_effect(5,0).pitch_scale = pow(2,pitch/12.0-5-1)
#	$spiccatoB.play()