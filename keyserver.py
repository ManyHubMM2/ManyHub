from flask import Flask, request, jsonify
from flask_cors import CORS
import sqlite3, secrets, string, time, os

app = Flask(__name__)
CORS(app)
DB = "keys.db"
MASTER_KEY = "AdminManyHub-HDFG6"
ADMIN_TOKEN = "CHANGE_ME_ADMIN_TOKEN_123"

def init_db():
    con = sqlite3.connect(DB)
    con.executescript("""
        CREATE TABLE IF NOT EXISTS keys (
            key TEXT PRIMARY KEY, name TEXT, days INTEGER,
            max_activations INTEGER, activations INTEGER DEFAULT 0,
            created_at INTEGER, expires_at INTEGER, hwid TEXT, active INTEGER DEFAULT 1
        );
    """)
    con.commit()
    con.close()

def gen_key(name):
    raw = name.upper().replace(" ", "")[:8]
    rand = ''.join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(8))
    return f"{raw}-{rand}"

@app.route("/api/activate", methods=["POST"])
def activate():
    data = request.json or {}
    key, hwid = data.get("key", "").strip(), data.get("hwid", "").strip()
    if key == MASTER_KEY:
        return jsonify({"ok": True, "name": "MASTER", "full": True})
        
    con = sqlite3.connect(DB)
    cur = con.cursor()
    cur.execute("SELECT name, expires_at, hwid FROM keys WHERE key = ? AND active = 1", (key,))
    row = cur.fetchone()
    if not row:
        con.close()
        return jsonify({"ok": False, "error": "invalid key"}), 404
    
    name, exp, bound_hwid = row
    if bound_hwid and bound_hwid != hwid:
        con.close()
        return jsonify({"ok": False, "error": "bound"}), 403
        
    now = int(time.time())
    if exp and now > exp:
        con.close()
        return jsonify({"ok": False, "error": "expired"}), 403
        
    con.close()
    return jsonify({"ok": True, "name": name})

@app.route("/api/admin/create", methods=["POST"])
def admin_create():
    if request.headers.get("X-Admin-Token") != ADMIN_TOKEN:
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    data = request.json or {}
    key = gen_key(data.get("name", "KEY"))
    now = int(time.time())
    days = int(data.get("days", 30))
    max_act = int(data.get("max_activations", 1))
    exp = now + days * 86400 if days > 0 else 0
    
    con = sqlite3.connect(DB)
    con.execute("INSERT INTO keys (key, name, days, max_activations, created_at, expires_at) VALUES (?, ?, ?, ?, ?, ?)",
                (key, data.get("name", "KEY"), days, max_act, now, exp))
    con.commit()
    con.close()
    return jsonify({"ok": True, "key": key})

init_db()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))