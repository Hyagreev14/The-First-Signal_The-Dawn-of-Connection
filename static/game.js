const message = document.getElementById("message");
const linkStatus = document.getElementById("linkStatus");
const cable = document.getElementById("cable");

async function request(path) {
    const response = await fetch(path, { method: "POST" });
    const data = await response.json();

    if (!response.ok) {
        throw new Error(data.error || "Request failed");
    }

    return data;
}

function render(state) {
    state.computers.forEach((computer) => {
        const card = document.getElementById(`computer-${computer.id}`);
        if (!card) return;

        const status = card.querySelector(".status");
        const button = document.querySelector(`.power-button[data-id="${computer.id}"]`);

        card.classList.toggle("online", computer.powered);
        status.textContent = computer.powered ? "ONLINE" : "OFFLINE";

        if (button) {
            button.textContent = computer.powered
                ? `POWER OFF · COMPUTER ${computer.id}`
                : `POWER ON · COMPUTER ${computer.id}`;
        }
    });

    const connected = state.ethernet_connected;
    linkStatus.textContent = connected ? "CONNECTED" : "DISCONNECTED";
    linkStatus.classList.toggle("connected", connected);
    cable.classList.toggle("connected", connected);

    if (connected) {
        message.textContent = "The first physical network connection has been established.";
    } else if (state.computers.length < 2) {
        message.textContent = "A second machine is waiting to exist.";
    } else {
        message.textContent = "Two computers exist. Now connect them.";
    }
}

document.querySelectorAll(".power-button").forEach((button) => {
    button.addEventListener("click", async () => {
        button.disabled = true;
        try {
            render(await request(`/api/power/${button.dataset.id}`));
        } catch (error) {
            message.textContent = error.message;
        } finally {
            button.disabled = false;
        }
    });
});

const buildButton = document.getElementById("buildButton");
if (buildButton) {
    buildButton.addEventListener("click", async () => {
        buildButton.disabled = true;
        try {
            await request("/api/build-computer");
            window.location.reload();
        } catch (error) {
            message.textContent = error.message;
            buildButton.disabled = false;
        }
    });
}

const connectButton = document.getElementById("connectButton");
if (connectButton) {
    connectButton.addEventListener("click", async () => {
        connectButton.disabled = true;
        try {
            render(await request("/api/connect-ethernet"));
        } catch (error) {
            message.textContent = error.message;
        } finally {
            connectButton.disabled = false;
        }
    });
}

render(window.__GAME_STATE__);
