# The First Signal

### Before we were connected.

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

**Current version:** `v0.001`

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
- Desktop-game simulation world
- Two computer devices represented as world objects
- **Build Computer action for creating additional computers**
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
- Initial IPv4 fields ready for the networking simulation
- Dark, cold, technical visual direction
- Foundation for future routers, switches, Wi-Fi, DHCP, IPv6, DNS, ISPs, ASNs, IXPs, and multiplayer
- Right-click device context menu
- Power devices on/off
- Connect and disconnect Ethernet
- Configure IPv4 addresses
- IPv4 validation and duplicate-address checks

More networking mechanics will be introduced gradually as development continues.

## 🛠️ Built With

- Godot Engine
- GDScript

The earlier browser prototype used Python, Flask, HTML, CSS, and JavaScript. It remains part of the project's development history.

## 📜 License

The First Signal's source code is licensed under the MIT License.

---

**The network begins with you.**
