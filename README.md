# vpn-util

A small Janet CLI for resolving VPN device hostnames and interacting with them.

It talks to a VPN management API to list devices, resolves hostnames through a
custom DNS server, and can open web pages, start SSH sessions, or print a
device's IP address.

## Commands

| Command | Description |
|---------|-------------|
| `ip <hostname>` | Resolve and print the IP address of a device |
| `web <hostname>` | Open `http://<hostname>` in the default browser |
| `ssh <user> <hostname>` | Start an SSH connection to the device |
| `list` | Print all device hostnames |
| `list-details` | Print full details for every device |
| `details <hostname>` | Print full details for one device |
| `set-psk <psk> [api_url]` | Write or update the config file |

## Dependencies

- [Janet](https://janet-lang.org/) (the language runtime)
- [jpm](https://github.com/janet-lang/jpm) (Janet package manager / build tool)
- A C compiler (for building native dependencies, e.g. `jurl`)
- `curl` development libraries (used by `jurl`)

## Building and installing with `jpm`

### Linux

```bash
# 1. Install Janet, jpm, and curl-dev. Examples:
#    Debian/Ubuntu:  sudo apt install janet jpm libcurl4-openssl-dev
#    Fedora:         sudo dnf install janet jpm libcurl-devel
#    Arch:           sudo pacman -S janet jpm curl

# 2. Build the executable
jpm build

# 3. Install to JANET_PATH/bin (usually ~/.local/bin)
jpm install

# Optional: copy shell completions manually
sudo cp completions/vpn.bash /usr/share/bash-completion/completions/vpn
sudo cp completions/_vpn /usr/share/zsh/site-functions/_vpn
```

The binary is built to `build/vpn`.

### Windows

```powershell
# 1. Install Janet and jpm
#    - Download the Windows installer from https://janet-lang.org/
#    - Or use a package manager if Janet is available there
# Make sure both `janet` and `jpm` are on your PATH.

# 2. Open a terminal (PowerShell or cmd) and build
jpm build

# 3. Install to %JANET_PATH%\bin (or the directory shown by `jpm show-paths`)
jpm install
```

On Windows the executable will be `build\vpn.exe`. `jpm install` places it in
your Janet binary directory; you can add that directory to your `PATH` if it is
not already there.

## Building and installing with Nix

This repository is a [flake](https://nixos.wiki/wiki/Flakes). It currently
supports Linux and macOS systems.

```bash
# Build from the local checkout
nix build

# Run directly without installing
nix run

# Enter a development shell with Janet, jpm, and janet-lsp
nix develop

# Install from the local checkout into your profile
nix profile install

# Install directly from GitHub into your profile
nix profile install "github:Rubicon-Development/vpn-util"
```

The flake also provides alternative outputs:

- `nix build .#vpn-c` — generated C source files (`vpn.c`, `janet.c`, `janet.h`)
- `nix build .#vpn-static` — statically linked-ish binary compiled from the
  generated C source

Shell completions are installed automatically by the Nix derivation.

## Configuration

The tool needs a JSON config file containing at least a `psk` key.

```json
{
  "psk": "your-pre-shared-key-here"
}
```

You can create it with the `set-psk` command:

```bash
vpn set-psk "your-pre-shared-key-here"

# Or also override the default API URL
vpn set-psk "your-pre-shared-key-here" "https://vpn.example.com:8080/get_devices_full"
```

### Config file lookup

The config is searched in this order:

1. `$VPN_CONFIG` — use this environment variable to point to any file
2. `$XDG_CONFIG_HOME/vpn/config.json`
3. `$HOME/.config/vpn/config.json`
4. `./vpn-config.json` in the current working directory (fallback)

`set-psk` writes to the first writable location from the list above.

## Usage examples

```bash
# List all devices
vpn list

# Print the IP address of one device
vpn ip my-device

# Open the device's local web page in your default browser
vpn web my-device

# SSH into a device
vpn ssh admin my-device

# Show all details for one device
vpn details my-device

# Show details for every device
vpn list-details

# Read hostnames from stdin
vpn list | vpn ip
```

## Environment variables

| Variable | Purpose |
|----------|---------|
| `VPN_CONFIG` | Override the path to the config JSON file |
| `XDG_CONFIG_HOME` | Base directory for the default config location |
| `HOME` | Used to locate `~/.config/vpn/config.json` |

## Shell completions

Bash and Zsh completions are included in the `completions/` directory.
When installing with Nix they are copied automatically. When installing with
`jpm`, copy them to your shell's completion directory manually.

