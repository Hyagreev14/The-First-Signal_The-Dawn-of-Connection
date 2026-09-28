const message = document.getElementById("message");
const linkStatus = document.getElementById("linkStatus");
const cable = document.getElementById("cable");
const connectButton = document.getElementById("connectButton");

async function request(path, options = {}) {
    const response = await fetch(path, { method: "POST", ...options });
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
        const ipLabel = card.querySelector(".ip-label");
        const button = document.querySelector(`.power-button[data-id="${computer.id}"]`);

        card.classList.toggle("online", computer.powered);
        status.textContent = computer.powered ? "ONLINE" : "OFFLINE";

        if (ipLabel) {
            ipLabel.textContent = computer.ip || "NO IP";
        }

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

    if (connectButton) {
        connectButton.textContent = connected ? "DISCONNECT ETHERNET" : "CONNECT ETHERNET";
    }

    if (connected && state.computers.every((computer) => computer.ip)) {
        message.textContent = "Two computers. One Ethernet link. One IPv4 LAN.";
    } else if (state.computers.length < 2) {
        message.textContent = "A second machine is waiting to exist.";
    } else if (!state.computers.every((computer) => computer.ip)) {
        message.textContent = "Assign both computers an IPv4 address.";
    } else {
        message.textContent = "IPv4 configured. Now connect the Ethernet link.";
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

const ipForm = document.getElementById("ipForm");
if (ipForm) {
    ipForm.addEventListener("submit", async (event) => {
        event.preventDefault();
        const button = ipForm.querySelector("button");
        button.disabled = true;

        try {
            const state = await request("/api/configure-ip", {
                body: new FormData(ipForm),
            });
            document.querySelectorAll(".ip-value").forEach((element, index) => {
                element.textContent = state.computers[index].ip;
            });
            render(state);
        } catch (error) {
            message.textContent = error.message;
        } finally {
            button.disabled = false;
        }
    });
}

render(window.__GAME_STATE__);
