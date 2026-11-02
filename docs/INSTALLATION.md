# Installation guide — Windows x64 and Linux x64

**ml_discord by 1Lorenzo**

The module currently supports **64-bit MTA servers on Windows and Linux**. Installation is done once at MTA server level; the Lua resource is started separately.

## 1. Download files

Open this repository's GitHub Releases page. Download the Windows or Linux asset for your server, and optionally the `example-resource` ZIP.

Do not put a Windows DLL on Linux or a Linux SO on Windows. Both assets are 64-bit.

## 2. Windows x64

1. Stop `MTA Server` completely.
2. Extract the Windows ZIP.
3. Copy `ml_discord.dll` to:

```text
MTA_SERVER_ROOT\x64\modules\ml_discord.dll
```

4. Create `x64\modules` if not present.
5. Edit `MTA_SERVER_ROOT\mods\deathmatch\mtaserver.conf` inside `<config>`:

```xml
<module src="ml_discord.dll" />
```

6. Save and start the MTA server again.

The Windows binary imports `WINHTTP.dll` and `lua5.1.dll` from the Windows/MTA runtime environment. It does not require you to distribute any separate Discord or DPP DLL.

## 3. Linux x64

Stop the Linux MTA server, then extract `ml_discord.so` to:

```text
MTA_SERVER_ROOT/x64/modules/ml_discord.so
```

The main `x64` directory is beside `mta-server64`. It is **not** `x64/x64` or `mods/deathmatch/modules`.

For an MTA server under your home folder, the commands look like this (adapt the ZIP path):

```bash
cd ~/mta-server/multitheftauto_linux_x64
mkdir -p x64/modules
cp /path/to/ml_discord.so x64/modules/ml_discord.so
file x64/modules/ml_discord.so
ldd x64/modules/ml_discord.so | grep 'not found' || true
```

Edit `mods/deathmatch/mtaserver.conf`:

```xml
<module src="ml_discord.so" />
```

Start the server again:

```bash
./mta-server64
```

The Linux asset provided here was inspected as an x86-64 ELF shared library. It dynamically links to **libcurl.so.4** and **libcrypto.so.3**, plus other system libraries pulled in by the host. These are OS-level runtime dependencies, not extra Discord modules shipped with this project.

On Ubuntu 24.04, packages providing those shared libraries are normally already available or can be installed as needed:

```bash
sudo apt update
sudo apt install -y libcurl4t64 libssl3t64 ca-certificates
```

Package names vary on other distributions. Check `ldd` if the module will not load. The supplied Linux binary requires GLIBC symbols through **GLIBC_2.38**, so it should be treated as an Ubuntu 24.04-era build rather than a universal Linux binary.

The Linux transport uses native WebSocket framing over an HTTPS/TLS libcurl connection. The system's `curl -V` output **does not** need to list `ws` or `wss` for this module to connect.

## 4. Load the resource

Create a server resource folder:

```text
MTA_SERVER_ROOT/mods/deathmatch/resources/ml_discord_demo/
    meta.xml
    server.lua
```

The example ZIP already contains those files. Open `server.lua` and fill the config values. Start the server, then from the MTA console:

```text
refresh
start ml_discord_demo
```

If you edit only `server.lua`, `restart ml_discord_demo` is enough. If you replace the **native binary**, shut down and start the entire MTA server to reload it.

## 5. Check it worked

On a successful startup, the server should load the module and the resource should print the ready username after Discord connects. If you enabled debug traces, the Linux version may show:

```text
[01] Gateway worker started; libcurl HTTPS + native RFC6455 WSS tunnel; version=0.9.0
[08] WSS handshake complete
[11] READY: bot online
```

These are expected trace examples, not a promise of identical messages from every installation. An `HTTP 200` reply from `/gateway/bot` alone is not the final ready state; the Gateway also needs to connect.

## 6. Updating an installed release

1. Stop the MTA server.
2. Back up the old `.dll` or `.so`.
3. Replace it in `x64/modules`.
4. Start the MTA server.
5. Verify `ready` and at least one command.

The bot token should stay on your server only and should not be stored in your public repository.

Official MTA docs: https://linux.multitheftauto.com/ and https://wiki.multitheftauto.com/wiki/Server_mtaserver.conf


## Source release v0.9.0
