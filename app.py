from flask import Flask, jsonify, render_template
import random

app = Flask(__name__)

game_state = {
    "powered": False,
    "mac": ":".join(f"{random.randint(0, 255):02X}" for _ in range(6)),
}


@app.get("/")
def index():
    return render_template("index.html", game=game_state)


@app.post("/api/power")
def toggle_power():
    game_state["powered"] = not game_state["powered"]
    return jsonify(game_state)


if __name__ == "__main__":
    app.run(debug=True)
