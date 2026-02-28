#!/usr/bin/env python3
"""
WebSocket relay server with lobby support.
"""

import asyncio
import json
import os
import random
import string
import time
import sys
from dataclasses import dataclass, field
import websockets

def gen_room_code() -> str:
    chars = string.ascii_uppercase + string.digits
    return ''.join(random.choices(chars, k=6))

@dataclass
class Client:
    ws: websockets.ServerConnection
    room: str | None = None
    player_id: int = -1
    is_host: bool = False
    username: str = "Player"
    hero: str = ""

@dataclass 
class Room:
    name: str
    clients: list[Client] = field(default_factory=list)
    next_id: int = 0
    max_players: int = 4
    settings: dict = field(default_factory=dict)  # map, gamemode, etc
    in_game: bool = False
    
    def add(self, client: Client) -> int:
        client.room = self.name
        client.player_id = self.next_id
        client.is_host = len(self.clients) == 0
        self.clients.append(client)
        self.next_id += 1
        return client.player_id
    
    def remove(self, client: Client):
        if client in self.clients:
            self.clients.remove(client)
            if client.is_host and self.clients:
                self.clients[0].is_host = True
    
    def get_lobby_state(self) -> dict:
        return {
            "type": "lobby_state",
            "room": self.name,
            "players": [
                {"id": c.player_id, "username": c.username, "hero": c.hero, "is_host": c.is_host}
                for c in self.clients
            ],
            "settings": self.settings,
            "in_game": self.in_game
        }

rooms: dict[str, Room] = {}
clients: dict[websockets.ServerConnection, Client] = {}

# --- Desync telemetry ---
POS_DESYNC_THRESHOLD = 50.0   # pixels
HP_DESYNC_THRESHOLD  = 5.0
REPORT_WINDOW        = 3.0    # seconds to collect reports before comparing

@dataclass
class DesyncTracker:
    pending: dict = field(default_factory=dict)  # reporter_id -> {t, p}
    last_check: float = 0.0

desync_trackers: dict[str, DesyncTracker] = {}  # room_code -> tracker

def _check_desync(room_code: str):
    tracker = desync_trackers.get(room_code)
    if not tracker or len(tracker.pending) < 2:
        return
    reporters = list(tracker.pending.keys())
    checked = set()
    for i, r1 in enumerate(reporters):
        for r2 in reporters[i+1:]:
            d1, d2 = tracker.pending[r1], tracker.pending[r2]
            all_pids = set(d1["p"].keys()) | set(d2["p"].keys())
            for pid in all_pids:
                if pid not in d1["p"] or pid not in d2["p"]:
                    continue
                p1, p2 = d1["p"][pid], d2["p"][pid]
                dx = abs(p1.get("x", 0) - p2.get("x", 0))
                dy = abs(p1.get("y", 0) - p2.get("y", 0))
                dist = (dx*dx + dy*dy) ** 0.5
                dhp = abs(p1.get("hp", 0) - p2.get("hp", 0))
                dmhp = abs(p1.get("mhp", 0) - p2.get("mhp", 0))
                dead_mismatch = p1.get("dead") != p2.get("dead")
                spec_mismatch = p1.get("spec") != p2.get("spec")
                if dist > POS_DESYNC_THRESHOLD or dhp > HP_DESYNC_THRESHOLD or dmhp > HP_DESYNC_THRESHOLD or dead_mismatch or spec_mismatch:
                    print(f"[DESYNC] room={room_code} player={pid} "
                          f"reporter_{r1}=(x={p1.get('x')},y={p1.get('y')},hp={p1.get('hp')}/{p1.get('mhp')},dead={p1.get('dead')},spec={p1.get('spec')}) "
                          f"reporter_{r2}=(x={p2.get('x')},y={p2.get('y')},hp={p2.get('hp')}/{p2.get('mhp')},dead={p2.get('dead')},spec={p2.get('spec')}) "
                          f"delta_pos={dist:.1f} delta_hp={dhp:.1f} delta_mhp={dmhp:.1f}",
                          flush=True)
    tracker.pending.clear()

def handle_pos_report(client: Client, msg: dict):
    room_code = client.room
    if not room_code:
        return
    if room_code not in desync_trackers:
        desync_trackers[room_code] = DesyncTracker()
    tracker = desync_trackers[room_code]
    reporter = str(msg.get("from", client.player_id))
    tracker.pending[reporter] = {"t": msg.get("t", 0), "p": msg.get("p", {})}
    now = time.monotonic()
    if now - tracker.last_check >= REPORT_WINDOW:
        tracker.last_check = now
        _check_desync(room_code)

async def handle(ws: websockets.ServerConnection):
    client = Client(ws=ws)
    clients[ws] = client
    print(f"Client connected")
    
    try:
        async for raw in ws:
            try:
                msg = json.loads(raw)
                await process(client, msg)
            except json.JSONDecodeError:
                await ws.send(json.dumps({"type": "error", "msg": "Invalid JSON"}))
    except websockets.ConnectionClosed:
        pass
    finally:
        await leave_room(client)
        del clients[ws]
        print(f"Client disconnected")

async def process(client: Client, msg: dict):
    t = msg.get("type", "")
    
    if t == "pos_report":
        handle_pos_report(client, msg)
    elif t == "host":
        await host_room(client, msg.get("username", "Host"))
    elif t == "join":
        await join_room(client, msg.get("room", "").upper(), msg.get("username", "Player"))
    elif t == "leave":
        await leave_room(client)
    elif t == "set_hero":
        await set_hero(client, msg.get("hero", ""))
    elif t == "set_settings":
        await set_settings(client, msg.get("settings", {}))
    elif t == "kick":
        await kick_player(client, msg.get("player_id", -1))
    elif t == "start_game":
        await start_game(client)
    elif t == "broadcast":
        await broadcast(client, msg.get("data", {}))
    elif t == "to_host":
        await send_to_host(client, msg.get("data", {}))
    elif t == "to_player":
        await send_to_player(client, msg.get("player_id", -1), msg.get("data", {}))
    else:
        await broadcast(client, msg)

async def host_room(client: Client, username: str):
    if client.room:
        await leave_room(client)
    
    # Generate unique room code
    code = gen_room_code()
    while code in rooms:
        code = gen_room_code()
    
    rooms[code] = Room(name=code)
    room = rooms[code]
    client.username = username[:15]
    player_id = room.add(client)
    
    await client.ws.send(json.dumps({
        "type": "hosted",
        "room": code,
        "player_id": player_id
    }))
    await broadcast_lobby_state(room)
    print(f"Room '{code}' created by {username}")

async def join_room(client: Client, room_code: str, username: str):
    if client.room:
        await leave_room(client)
    
    room_code = room_code.upper()
    
    if room_code not in rooms:
        await client.ws.send(json.dumps({"type": "error", "msg": "Room not found"}))
        return
    
    room = rooms[room_code]
    
    if len(room.clients) >= room.max_players:
        await client.ws.send(json.dumps({"type": "error", "msg": "Room is full"}))
        return
    
    if room.in_game:
        await client.ws.send(json.dumps({"type": "error", "msg": "Game already in progress"}))
        return
    
    client.username = username[:15]
    player_id = room.add(client)
    
    await client.ws.send(json.dumps({
        "type": "joined",
        "room": room_code,
        "player_id": player_id,
        "is_host": client.is_host,
        "players": [c.player_id for c in room.clients]
    }))
    
    # Notify others
    msg = json.dumps({"type": "player_joined", "player_id": player_id, "username": username})
    for c in room.clients:
        if c != client:
            await c.ws.send(msg)
    
    await broadcast_lobby_state(room)
    print(f"{username} joined room '{room_code}'")

async def leave_room(client: Client):
    if not client.room:
        return
    
    room = rooms.get(client.room)
    if not room:
        return
    
    was_host = client.is_host
    pid = client.player_id
    room_name = client.room
    room.remove(client)
    
    for c in room.clients:
        await c.ws.send(json.dumps({"type": "player_left", "player_id": pid}))
        if was_host and c.is_host:
            await c.ws.send(json.dumps({"type": "became_host"}))
    
    if room.clients:
        await broadcast_lobby_state(room)
    else:
        del rooms[room_name]
        desync_trackers.pop(room_name, None)
        print(f"Room '{room_name}' closed")
    
    client.room = None
    client.player_id = -1
    client.hero = ""

async def set_hero(client: Client, hero: str):
    if not client.room:
        return
    room = rooms.get(client.room)
    if not room:
        return
    
    client.hero = hero
    await broadcast_lobby_state(room)

async def set_settings(client: Client, settings: dict):
    if not client.room or not client.is_host:
        return
    room = rooms.get(client.room)
    if not room:
        return
    
    room.settings.update(settings)
    await broadcast_lobby_state(room)

async def kick_player(client: Client, target_id: int):
    if not client.room or not client.is_host:
        return
    room = rooms.get(client.room)
    if not room:
        return
    
    for c in room.clients:
        if c.player_id == target_id and c != client:
            await c.ws.send(json.dumps({"type": "kicked"}))
            await leave_room(c)
            break

async def start_game(client: Client):
    if not client.room or not client.is_host:
        return
    room = rooms.get(client.room)
    if not room:
        return
    
    if len(room.clients) < 2:
        await client.ws.send(json.dumps({"type": "error", "msg": "Need at least 2 players"}))
        return
    
    room.in_game = True
    
    # Send game_start to all players with full player info
    msg = json.dumps({
        "type": "game_start",
        "players": [
            {"id": c.player_id, "username": c.username, "hero": c.hero, "is_host": c.is_host}
            for c in room.clients
        ],
        "settings": room.settings
    })
    for c in room.clients:
        await c.ws.send(msg)
    
    print(f"Game started in room '{client.room}'")

async def broadcast_lobby_state(room: Room):
    state = json.dumps(room.get_lobby_state())
    for c in room.clients:
        await c.ws.send(state)

async def broadcast(sender: Client, data: dict):
    if not sender.room:
        return
    room = rooms.get(sender.room)
    if not room:
        return
    
    msg = json.dumps({"type": "relay", "from": sender.player_id, "data": data})
    for c in room.clients:
        if c != sender:
            await c.ws.send(msg)

async def send_to_host(sender: Client, data: dict):
    if not sender.room:
        return
    room = rooms.get(sender.room)
    if not room:
        return
    
    for c in room.clients:
        if c.is_host and c != sender:
            await c.ws.send(json.dumps({"type": "relay", "from": sender.player_id, "data": data}))
            break

async def send_to_player(sender: Client, target_id: int, data: dict):
    if not sender.room:
        return
    room = rooms.get(sender.room)
    if not room:
        return
    
    for c in room.clients:
        if c.player_id == target_id:
            await c.ws.send(json.dumps({"type": "relay", "from": sender.player_id, "data": data}))
            break

async def main():
    port = int(os.environ.get("PORT", 8080))
    print(f"Starting relay server on port {port}")
    async with websockets.serve(handle, "0.0.0.0", port):
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())
