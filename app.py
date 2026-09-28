from flask import Flask, jsonify, render_template, request
import ipaddress
import random

app = Flask(__name__)


def generate_mac():
    return ":".join(f"{random.randint(0, 255):02X}" for _ in range(6))


game_state = {
    "computers": [
        {"id": 1, "mac": generate_mac(), "powered": False, "ip": None},
    ],
    "ethernet_connected": False,
}


@app.get("/")
def index():
    return render_template("index.html", game=game_state)


@app.post("/api/power/<int:computer_id>")
def toggle_power(computer_id):
    computer = next(
        (computer for computer in game_state["computers"] if computer["id"] == computer_id),
        None,
    )

    if computer is None:
        return jsonify({"error": "Computer not found"}), 404

    computer["powered"] = not computer["powered"]

    if not all(computer["powered"] for computer in game_state["computers"]):
        game_state["ethernet_connected"] = False

    return jsonify(game_state)


@app.post("/api/build-computer")
def build_computer():
    if len(game_state["computers"]) >= 2:
        return jsonify({"error": "Only two computers exist in v0.0002"}), 400

    game_state["computers"].append(
        {"id": 2, "mac": generate_mac(), "powered": False, "ip": None}
    )
    return jsonify(game_state)


@app.post("/api/connect-ethernet")
def connect_ethernet():
    if len(game_state["computers"]) < 2:
        return jsonify({"error": "Build the second computer first"}), 400

    if not all(computer["powered"] for computer in game_state["computers"]):
        return jsonify({"error": "Both computers must be powered on"}), 400

    game_state["ethernet_connected"] = not game_state["ethernet_connected"]
    return jsonify(game_state)


@app.post("/api/configure-ip")
def configure_ip():
    if len(game_state["computers"]) < 2:
        return jsonify({"error": "Build the second computer first"}), 400

    if not all(computer["powered"] for computer in game_state["computers"]):
        return jsonify({"error": "Both computers must be powered on"}), 400

    if not game_state["ethernet_connected"]:
        return jsonify({"error": "Connect the Ethernet link first"}), 400

    values = []
    for computer in game_state["computers"]:
        raw_ip = request.form.get(f"ip_{computer['id']}", "").strip()

        try:
            address = ipaddress.IPv4Address(raw_ip)
        except ipaddress.AddressValueError:
            return jsonify({"error": f"Computer {computer['id']} has an invalid IPv4 address"}), 400

        values.append(address)

    if values[0] == values[1]:
        return jsonify({"error": "Both computers cannot use the same IP address"}), 400

    networks = [ipaddress.IPv4Network(f"{address}/24", strict=False) for address in values]

    if networks[0] != networks[1]:
        return jsonify({"error": "Both computers must be on the same /24 subnet"}), 400

    for computer, address in zip(game_state["computers"], values):
        computer["ip"] = str(address)

    return jsonify(game_state)


if __name__ == "__main__":
    app.run(debug=True)
