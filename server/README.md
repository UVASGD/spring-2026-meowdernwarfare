## Local Testing

```bash
cd server
pip install -r requirements.txt
python relay.py
```

Server runs on `ws://localhost:8080`. Press F6 in-game to connect.

## Deploy to fly.io

1. Install fly CLI: https://fly.io/docs/flyctl/install/

2. Sign up (free): 
```bash
fly auth signup
```

3. Deploy:
```bash
cd server
fly launch --name game-name
fly deploy
```

4. Your server URL will be: `wss://game-name.fly.dev`

5. Update `ONLINE_SERVER` in `game.gd` with your URL
Anyone else playing with you must have the same ONLINE_SERVER URl as you 
