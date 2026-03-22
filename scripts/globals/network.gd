extends Node

# Network singleton - handles WebSocket connection to relay server

signal connected
signal disconnected
signal error(msg: String)
signal hosted(room_code: String, player_id: int)
signal joined_room(player_id: int, is_host: bool)
signal player_joined(player_id: int, username: String)
signal player_left(player_id: int)
signal became_host
signal kicked
signal lobby_state_updated(state: Dictionary)
signal game_started(players: Array, settings: Dictionary)
signal message_received(from_id: int, data: Dictionary)

var socket: WebSocketPeer = null
var server_url: String = ""
var room_code: String = ""
var my_player_id: int = -1
var my_username: String = ""
var is_host: bool = false
var players_in_room: Array[int] = []
var lobby_state: Dictionary = {}

enum State { DISCONNECTED, CONNECTING, CONNECTED }
var state: State = State.DISCONNECTED

func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	if socket == null:
		return
	
	socket.poll()
	
	match socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if state == State.CONNECTING:
				state = State.CONNECTED
				connected.emit()
			
			while socket != null and socket.get_available_packet_count() > 0:
				var packet = socket.get_packet()
				_handle_message(packet.get_string_from_utf8())
		
		WebSocketPeer.STATE_CLOSING:
			pass
		
		WebSocketPeer.STATE_CLOSED:
			state = State.DISCONNECTED
			socket = null
			set_process(false)
			disconnected.emit()

func connect_to_server(url: String) -> Error:
	if state != State.DISCONNECTED:
		disconnect_from_server()
	
	server_url = url
	socket = WebSocketPeer.new()
	var err = socket.connect_to_url(url)
	
	if err != OK:
		push_error("Network: Failed to connect - ", err)
		socket = null
		return err
	
	state = State.CONNECTING
	set_process(true)
	return OK

func disconnect_from_server() -> void:
	if socket:
		socket.close()
	socket = null
	state = State.DISCONNECTED
	my_player_id = -1
	is_host = false
	room_code = ""
	players_in_room.clear()
	lobby_state.clear()
	set_process(false)

func host_room(username: String) -> void:
	my_username = username
	_send({"type": "host", "username": username})

func join_room(code: String, username: String) -> void:
	my_username = username
	_send({"type": "join", "room": code.to_upper(), "username": username})

func leave_room() -> void:
	_send({"type": "leave"})
	room_code = ""
	my_player_id = -1
	players_in_room.clear()
	lobby_state.clear()

func set_hero(hero: String) -> void:
	_send({"type": "set_hero", "hero": hero})

func set_settings(settings: Dictionary) -> void:
	_send({"type": "set_settings", "settings": settings})

func kick_player(player_id: int) -> void:
	_send({"type": "kick", "player_id": player_id})

func start_game() -> void:
	_send({"type": "start_game"})

func broadcast(data: Dictionary) -> void:
	_send({"type": "broadcast", "data": data})

func send_to_host(data: Dictionary) -> void:
	_send({"type": "to_host", "data": data})

func send_to_player(player_id: int, data: Dictionary) -> void:
	_send({"type": "to_player", "player_id": player_id, "data": data})

func is_online() -> bool:
	return state == State.CONNECTED

func _send(data: Dictionary) -> void:
	if socket == null or state != State.CONNECTED:
		return
	socket.send_text(JSON.stringify(data))

func _handle_message(raw: String) -> void:
	var data = JSON.parse_string(raw)
	if data == null:
		return
	
	var msg_type = data.get("type", "")
	
	match msg_type:
		"hosted":
			room_code = data.get("room", "")
			my_player_id = int(data.get("player_id", -1))
			is_host = true
			hosted.emit(room_code, my_player_id)
		
		"joined":
			room_code = data.get("room", "")
			my_player_id = int(data.get("player_id", -1))
			is_host = data.get("is_host", false)
			players_in_room.clear()
			for pid in data.get("players", []):
				players_in_room.append(int(pid))
			joined_room.emit(my_player_id, is_host)
		
		"player_joined":
			var pid = int(data.get("player_id", -1))
			var uname = data.get("username", "Player")
			if pid >= 0 and pid not in players_in_room:
				players_in_room.append(pid)
			player_joined.emit(pid, uname)
		
		"player_left":
			var pid = int(data.get("player_id", -1))
			players_in_room.erase(pid)
			player_left.emit(pid)
		
		"became_host":
			is_host = true
			became_host.emit()
		
		"kicked":
			kicked.emit()
			room_code = ""
			my_player_id = -1
			players_in_room.clear()
		
		"lobby_state":
			lobby_state = data
			lobby_state_updated.emit(data)
		
		"game_start":
			var players = data.get("players", [])
			var settings = data.get("settings", {})
			game_started.emit(players, settings)
		
		"error":
			var msg = data.get("msg", "Unknown error")
			error.emit(msg)
		
		"relay":
			var from_id = int(data.get("from", -1))
			var payload = data.get("data", {})
			message_received.emit(from_id, payload)
