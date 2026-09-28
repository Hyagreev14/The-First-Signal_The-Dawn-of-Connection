# The First Signal

### The Dawn of Connection

**The First Signal** is a network-building simulation game where you start with a single computer and build the connected world from the ground up.

Place machines. Build connections. Create networks. Discover new technologies. Expand.

What begins as one computer can eventually become a vast interconnected world.

## 🎮 Gameplay

- Start with a single computer
- Build physical connections
- Create and expand networks
- Discover networking technologies
- Build infrastructure
- Grow from a tiny network into a connected world

The networking isn't just the setting — **it's the game.**

## 🚧 Development

**Current version:** `v0.002`

The project has moved from the early browser prototype into a native Godot game.

### v0.0001 — Browser Prototype

- One computer
- Generated MAC address
- Power system
- Basic browser interface

### v0.0002 — Browser Prototype

- Two computers
- Generated MAC address for each computer
- Individual computer power controls
- Physical Ethernet connection between computers
- Ethernet link only works when both computers are powered on
- Basic network visualization

### v0.0003 — Browser Prototype

- IPv4 addresses for computers
- Manual IPv4 configuration
- IPv4 validation
- Duplicate IP detection
- Same /24 subnet validation
- Basic IPv4 LAN state

### v0.001 — The Simulation Foundation

- Native Godot 2D game project
- Empty network world at game start
- **Computers must be manually built by the player**
- Build Computer action for creating computers
- Newly built computers receive a unique generated MAC address
- New computers start powered off and become immediately selectable
- Automatic placement for newly built computers
- Drag devices around the network world
- Pan the world with the middle mouse button
- Zoom with the mouse wheel
- Select devices and inspect their state
- Individual power states
- Generated MAC addresses
- Physical Ethernet link visualization
- Animated data packet moving across an active link
- Independent asynchronous packet motion in each direction, so bidirectional traffic is not perfectly coordinated
- Initial IPv4 fields ready for the networking simulation
- Dark, cold, technical visual direction
- Foundation for future routers, switches, Wi-Fi, DHCP, IPv6, DNS, ISPs, ASNs, IXPs, and multiplayer
- Right-click device context menu
- Power devices on/off
- Connect and disconnect Ethernet
- Choose the exact computer to connect Ethernet to
- Configure IPv4 addresses
- IPv4 validation and duplicate-address checks

### v0.002 — Economy, Controls & Testing

- Player starts with **$1000**
- Building a computer costs **$100**
- Connecting an Ethernet cable costs **$25**
- First successful Ethernet connection rewards **$150**
- First successful IPv4 configuration rewards **$50**
- Currency HUD
- Insufficient-funds validation
- On-screen action controls for the selected computer
- Keyboard shortcuts:
  - **F1** — Power
  - **F2** — Connect Ethernet
  - **F3** — Rename
  - **F4** — Configure IPv4
  - **F9** — Inspect
  - **F6** — Center view
  - **F7** — Zoom in
  - **F8** — Zoom out
  - **Delete** — Delete selected computer
  - **Esc** — Pause / resume the simulation
- Development-only redeem code system for unlimited-funds testing
- Test mode displays unlimited funds and bypasses economy costs
- Existing right-click controls remain available as a secondary interaction method

More networking mechanics will be introduced gradually as development continues.

## 🛠️ Built With

- Godot Engine
- GDScript

The earlier browser prototype used Python, Flask, HTML, CSS, and JavaScript. It remains part of the project's development history.

## 📜 License

The First Signal's source code is licensed under the MIT License.

---

**The network begins with you.**
