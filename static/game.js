const button = document.getElementById("powerButton");
const computer = document.getElementById("computer");
const status = document.getElementById("status");
const power = document.getElementById("power");

function render(state) {
    const online = state.powered;
    computer.classList.toggle("online", online);
    status.textContent = online ? "ONLINE" : "OFFLINE";
    power.textContent = online ? "ON" : "OFF";
    button.textContent = online ? "POWER OFF" : "POWER ON";
}

button.addEventListener("click", async () => {
    button.disabled = true;
    try {
        const response = await fetch("/api/power", { method: "POST" });
        if (!response.ok) throw new Error("Power request failed");
        render(await response.json());
    } catch (error) {
        console.error(error);
    } finally {
        button.disabled = false;
    }
});
