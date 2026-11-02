# ml_discord

**Native Discord module for Multi Theft Auto: San Andreas**

**Created by 1Lorenzo**  
**Release:** v0.9.0  
**Currently compatible with x64 only: Windows x64 and Linux x64.**  
**Language:** Native C++ module with a server-side Lua API.

`ml_discord` brings a Discord bot directly into a MTA:SA server resource. You can listen to Discord messages, send messages to channels, create embeds, use buttons and slash commands, set the bot presence, work with webhooks, make Discord REST requests, and connect MTA server events with Discord. The bot logic can stay in one normal `server.lua` file.

## Downloads

After the new Windows and Linux builds are compiled and uploaded, open GitHub **Releases** and download the file for your platform. **v0.9.0 binaries are not included in this source checkout.**

| Release asset | Platform | File inside |
| --- | --- | --- |
| `ml_discord-v0.9.0-windows-x64.zip` | Windows 64-bit MTA server | `ml_discord.dll` |
| `ml_discord-v0.9.0-linux-x64.zip` | Linux 64-bit MTA server | `ml_discord.so` |

Use the **Releases** assets for ready-made modules. The normal GitHub **Code → Download ZIP** option is the repository documentation and examples, not the platform binaries.

## Highlights

- One native module file for each supported platform, with no extra Discord library distributed with it.
- Uses Discord Gateway for live events and Discord REST API for requests.
- Message creation, message updates, message deletion and interaction events.
- Native guild member role management: `addRole`, `giveRole`, `removeRole`, `remRole`.
- Look up Discord members, users, member role IDs and guild role objects.
- `guildMemberUpdate(oldMember, newMember)` and `userUpdate(oldUser, newUser)` event signatures.
- `guildMemberRoleAdd`, `guildMemberRoleRemove`, `guildMemberNicknameUpdate` change notifications.
- Sends normal text, embeds and Discord message components (buttons).
- Message helpers: reply, edit, delete and react.
- Promises with `:next()` and `:catch()` callbacks for REST requests.
- A sent message from `:next()` also has message methods such as `:edit()`.
- Interaction helpers: reply, defer, deferUpdate and update.
- Bot status and activity updates.
- Raw Discord REST requests and Discord webhook messages.
- Automatic Gateway heartbeat/reconnect and handling of Discord rate limits.
- All Lua event callbacks run through MTA module pulse; the network threads do not call Lua directly.

## Quick start

### 1. Get a Discord application

Create a bot in the [Discord Developer Portal](https://discord.com/developers/applications), enable the intents your script needs, and invite the bot with the correct permissions. See [Discord setup](docs/DISCORD_SETUP.md).

### 2. Install the module

**Windows x64**

1. Stop your MTA server.
2. Extract `ml_discord.dll` from the Windows asset.
3. Put it in `<MTA server root>/x64/modules/ml_discord.dll`.
4. Add this inside the `<config>` element of `mods/deathmatch/mtaserver.conf`:

```xml
<module src="ml_discord.dll" />
```

**Linux x64**

1. Stop your MTA server.
2. Extract `ml_discord.so` from the Linux asset.
3. Put it in `<MTA server root>/x64/modules/ml_discord.so`.
4. Add this inside the `<config>` element of `mods/deathmatch/mtaserver.conf`:

```xml
<module src="ml_discord.so" />
```

You only need the module entry for your current operating system. Start the MTA server again to load or update the native binary. Restarting the Lua resource alone does **not** reload a changed `.dll` or `.so`.

The Linux build relies on normal system runtime libraries, in particular `libcurl.so.4` and OpenSSL 3 `libcrypto.so.3`. The uploaded Linux release was built on Ubuntu 24.04; older Linux distributions may not meet its GLIBC requirements. See [installation details](docs/INSTALLATION.md).

### 3. Add the example resource

Extract the example asset into:

```text
<MTA server root>/mods/deathmatch/resources/ml_discord_demo/
    meta.xml
    server.lua
```

Open `server.lua`, set your bot token and desired IDs in the config section, then start the resource:

```text
refresh
start ml_discord_demo
```

Keep your real token out of your public GitHub commits.

### 4. Test the bot

In a Discord channel where the bot can read and send messages:

```text
!ping
!players
!embed
!buttons
!help
```

`!ping` sends an initial message and then edits the bot's reply with the measured elapsed time. This is a message round-trip measurement, **not** the Discord Gateway heartbeat latency. The buttons send an ephemeral response to the user who clicked one.

## Smallest possible Lua example

Create a server-side Lua resource with:

```lua
local I = Discord.Intents
local Bot = Discord:Instance({
    intents = I.GUILDS + I.GUILD_MEMBERS + I.GUILD_MESSAGES + I.MESSAGE_CONTENT,
    debug = false
})

Bot:on("ready", function()
    outputDebugString("Discord bot connected: " .. tostring(Bot.user and Bot.user.username))
    Bot:setActivity("MTA:SA")
end)

Bot:on("messageCreate", function(message)
    if message.author and message.author.bot then return end
    if message.content == "!ping" then
        message:reply("Pong from MTA!")
    end
end)

Bot:on("error", function(err)
    outputDebugString("Discord error: " .. tostring(err), 1)
end)

local ok, err = Bot:login("YOUR_BOT_TOKEN")
if not ok then
    outputDebugString("Discord login failed: " .. tostring(err), 1)
end
```

This code is **server-side only**. You dont need `require`, `loadstring`, a Lua Discord package, or a separate bot process.

## API overview

| API | What it does |
| --- | --- |
| `Discord:Instance(options)` | Creates the native Discord client object for this resource. |
| `Discord.Intents` | Gateway intent bit constants. |
| `Client:on(event, callback)` | Keeps a listener registered until removed or resource shutdown. |
| `Client:once(event, callback)` | Calls the listener for the next matching event only. |
| `Client:off(event[, callback])` | Removes a single callback or all callbacks for the event. |
| `Client:login(token)` | Starts native Gateway and REST workers. |
| `Client:destroy()` | Stops and removes the client. |
| `Client:setActivity(text)` | Sets a playing activity. |
| `Client:setPresence(options)` | Sets status, activity and activity type. |
| `Client:send(channelId, payload)` | Sends a Discord channel message. |
| `Client:addRole(guildId, userId, roleId)` / `giveRole` | Assigns a guild role to a member. |
| `Client:removeRole(guildId, userId, roleId)` / `remRole` | Removes a member's guild role. |
| `Client:getMember(guildId, userId)` | Fetches a member and seeds the snapshot cache. |
| `Client:getRoles(guildId, userId)` | Returns a member's role ID list. |
| `Client:getRoles(guildId)` / `getGuildRoles(guildId)` | Returns the guild's role objects. |
| `Client:getUser(userId)` | Fetches a Discord user. |
| `Client:editMessage(channelId, messageId, payload)` | Edits a bot message. |
| `Client:request(method, path[, body])` | Queues a Discord REST API request. |
| `Client:sendWebhook(url, payload)` | Sends a message using a Discord webhook URL. |
| `Client.webhooks:send(url, payload)` | Alias for webhook sending. |
| `message:reply(payload)` | Replies to a Discord message. |
| `message:edit(payload)` | Edits the message (Discord permissions apply). |
| `message:delete()` | Deletes a message (Discord permissions apply). |
| `message:react(emoji)` | Adds a reaction. |
| `interaction:reply(payload[, ephemeral])` | Replies to a slash command or component interaction. |
| `interaction:defer([ephemeral])` | Acknowledges an interaction for later processing. |
| `interaction:deferUpdate()` | Acknowledges a component without changing the message. |
| `interaction:update(payload)` | Updates the component's original message. |
| `promise:next(onSuccess[, onFailure])` | Runs callbacks when the request completes. |
| `promise:catch(onFailure)` | Handles failed requests. |

**Full documentation:** [API Reference](docs/API_REFERENCE.md) — every method, every intent, all public fields, payload format, events, return types and examples.

## Documentation

- [Member roles and change events](docs/MEMBERS_AND_ROLES.md)
- [Build from source (VS Code / Visual Studio)](BUILD.md)
- [Full API Reference](docs/API_REFERENCE.md)
- [Installation on Windows and Linux](docs/INSTALLATION.md)
- [Discord Developer Portal and bot permissions](docs/DISCORD_SETUP.md)
- [Examples and patterns](docs/EXAMPLES.md)
- [Troubleshooting and common errors](docs/TROUBLESHOOTING.md)
- [Transport, lifecycle and limitations](docs/TECHNICAL_NOTES.md)
- [Release notes](RELEASE_NOTES.md)
- [GitHub publishing guide](PUBLISH_GITHUB.md)

## Compatibility

| Item | Support |
| --- | --- |
| Windows MTA server | x64 |
| Linux MTA server | x64 |
| MTA resource Lua | Server-side |
| Lua-side external dependencies | None |
| Discord bot process outside MTA | Not needed |
| Runtime access to Discord | Required |

The Windows binary uses WinHTTP. The Linux binary uses libcurl for HTTPS and a native RFC 6455 WebSocket tunnel over a verified TLS connection. The Linux WebSocket implementation does not need `ws` / `wss` URL support in the system libcurl build.

The v0.9.0 binary files have to be compiled from this source before publishing the release. Windows and Linux x64 are the current targets. No claim is made about untested servers or distributions.

## Member updates and role controls

```lua
local guildId = "YOUR_GUILD_ID"
local memberId = "YOUR_USER_ID"
local roleId = "YOUR_ROLE_ID"

Bot:addRole(guildId, memberId, roleId):next(function()
    outputDebugString("Role assigned")
end):catch(function(err)
    outputDebugString(tostring(err.message), 1)
end)

Bot:on("guildMemberUpdate", function(oldMember, newMember)
    if oldMember then
        outputDebugString(tostring(oldMember.nick) .. " -> " .. tostring(newMember.nick))
    end
end)

Bot:on("guildMemberRoleAdd", function(member, changedRoleId)
    outputDebugString("Added role " .. tostring(changedRoleId))
end)
```

These events require **Server Members Intent** enabled in Discord Developer Portal and `Discord.Intents.GUILD_MEMBERS` in Lua. Role writes need `Manage Roles` and correct role hierarchy. When a member isnt cached yet, `oldMember` is `nil` and individual role differences are not emitted until a baseline exists. `Client:getMember` or `Client:getRoles` can seed one.

Changing an unrelated person's global Discord username is **not guaranteed** to trigger a Gateway event for the bot. The `userUpdate` event works for updates Discord actually delivers, or when updated user details are present in a member event. See [Members & roles](docs/MEMBERS_AND_ROLES.md).

## Credits

**Created and maintained by 1Lorenzo.**
For help [Join Discord](https://discord.gg/92pJgMVgAN).
