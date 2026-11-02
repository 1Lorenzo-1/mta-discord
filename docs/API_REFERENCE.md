# ml_discord — complete API reference

**Author: 1Lorenzo**  
**Release: v0.9.0 · Windows x64 / Linux x64**

This reference describes the public Lua interface in the module source associated with this release. All calls are made from a server-side MTA resource. Discord's API permissions, rate limits, payload size and Gateway intents still apply.

## 1. How the Lua API works

When MTA loads the native module, it registers the global table `Discord` for server-side resources. There is no Lua `require()` call.

```lua
local Bot = Discord:Instance({
    intents = Discord.Intents.GUILDS
        + Discord.Intents.GUILD_MEMBERS
        + Discord.Intents.GUILD_MESSAGES
        + Discord.Intents.MESSAGE_CONTENT,
    debug = false,
    maxQueue = 4096
})
```

`Discord:Instance(options)` accepts a Lua options table. The options are:

| Name | Type | Default | Meaning |
| --- | --- | --- | --- |
| `intents` | nonnegative integer bitmask | `GUILDS + GUILD_MESSAGES` | Which Gateway events Discord should send. |
| `debug` | boolean | `false` | Enables more transport trace messages. |
| `maxQueue` | integer | `4096` | Max buffered events per client, clamped to `128` through `32768`. |

The `Client` is a Lua table backed by a native client handle. A client object gives access to event handlers, REST actions, login and presence.

`Discord.version` now reports `0.9.0`. The module metadata and transport trace strings were updated for this source version too. Rebuild the DLL and SO to see these identifiers in the running server.

### Understanding Discord IDs

Use **strings** for Discord IDs. They are large snowflake values and Lua 5.1 numbers may lose precision.

```lua
local CHANNEL_ID = "123456789012345678"
local GUILD_ID = "123456789012345678"
local APPLICATION_ID = "123456789012345678"
```

Never do `Client:send(123456789012345678, "hi")`. This module checks API ID parameters and expects decimal string values. Discord JSON fields such as `id` and `channel_id` are converted into strings on the Lua side when returned as string values; aliases are provided where documented.

### Event callbacks and thread handling

Network workers receive packets and handle HTTPS asynchronously. They queue results for the MTA `DoPulse()` callback. Your Lua handlers are invoked on the MTA Lua side, not by random background threads. Do not block the MTA thread with long-running callbacks.

## 2. Every exported `Discord.Intents` constant

Each constant has the value `2 ^ bit`. Add the values together to create the intent bitmask. Use each intent at most once in the sum.

| Constant | Bit | Purpose |
| --- | ---: | --- |
| `GUILDS` | 0 | Guild/server events and general guild state. |
| `GUILD_MEMBERS` | 1 | Member-related guild events; privileged. |
| `GUILD_MODERATION` | 2 | Moderation-related events. |
| `GUILD_EMOJIS_AND_STICKERS` | 3 | Emoji and sticker updates. |
| `GUILD_INTEGRATIONS` | 4 | Integration events. |
| `GUILD_WEBHOOKS` | 5 | Webhook update events. |
| `GUILD_INVITES` | 6 | Guild invite events. |
| `GUILD_VOICE_STATES` | 7 | Voice state updates. |
| `GUILD_PRESENCES` | 8 | Presence events; privileged. |
| `GUILD_MESSAGES` | 9 | Messages created, changed or removed in guild channels. |
| `GUILD_MESSAGE_REACTIONS` | 10 | Reactions added or removed in guild channels. |
| `GUILD_MESSAGE_TYPING` | 11 | Typing events in guild channels. |
| `DIRECT_MESSAGES` | 12 | Direct message events. |
| `DIRECT_MESSAGE_REACTIONS` | 13 | DM reaction events. |
| `DIRECT_MESSAGE_TYPING` | 14 | DM typing events. |
| `MESSAGE_CONTENT` | 15 | Access to message content where Discord requires this privileged intent. |
| `GUILD_SCHEDULED_EVENTS` | 16 | Guild scheduled-event changes. |
| `AUTO_MODERATION_CONFIGURATION` | 20 | Auto-moderation rule changes. |
| `AUTO_MODERATION_EXECUTION` | 21 | Auto-moderation actions. |
| `GUILD_MESSAGE_POLLS` | 24 | Guild poll events. |
| `DIRECT_MESSAGE_POLLS` | 25 | Direct message poll events. |

The bot must also be allowed to use relevant privileged intents in Discord Developer Portal. Gateway requests can fail with code `4014` if a privileged intent is requested but not approved/enabled. If you only want an ordinary `!ping` prefix bot, `GUILDS + GUILD_MESSAGES + MESSAGE_CONTENT` is a sensible starting point.

## 3. Client lifecycle

### `Client:login(token)`

Starts the Gateway and REST workers with the bot token. Return values:

- On success: `true`. This means the background workers started; **it does not mean the bot is online yet**.
- On immediate error: `nil, errorMessage`.

Wait for the `ready` event before sending initial startup announcements.

```lua
local ok, err = Bot:login("YOUR_BOT_TOKEN")
if not ok then
    outputDebugString("Discord login error: " .. tostring(err), 1)
end
```

Calling `login` twice on one client is not allowed. Use `Client:on("error", ...)` for asynchronous errors such as invalid Gateway intents, connection problems or HTTP failures.

### `Client:destroy()`

Stops the client and releases its native state. Returns `true` on success or `nil, errorMessage` if the client cannot be used. Registered events and pending requests are discarded with the client. Native client cleanup also runs when the MTA resource stops or the module shuts down.

### `Client.user`

After the `ready` event, `Client.user` contains the bot user's information as supplied by Discord's READY event. Common fields include `id`, `username`, `bot` and `avatar`. This field may be absent before READY.

### `Client.webhooks`

A table exposing `Client.webhooks:send(url, payload)`, an alias for `Client:sendWebhook(url, payload)`.

## 4. Registering and removing event listeners

### `Client:on(eventName, callback)`

Adds a persistent listener. Returns the client for chaining.

```lua
local function onReady(data)
    outputDebugString("Bot is ready")
end
Bot:on("ready", onReady)
```

### `Client:once(eventName, callback)`

Runs for only the next matching event and is removed automatically.

```lua
Bot:once("ready", function(data)
    outputDebugString("First ready event")
end)
```

### `Client:off(eventName[, callback])`

Removes the exact callback passed for that event. If callback is omitted, removes all handlers for that event.

```lua
local handler = function(message) outputDebugString("message received") end
Bot:on("messageCreate", handler)
Bot:off("messageCreate", handler)
```

Event names are case-sensitive. A wrong event name may register fine but never fire.

### Gateway event names

Discord Gateway names such as `MESSAGE_CREATE` are exposed using lower camel case, for example `messageCreate`. The special `GUILD_ROLE_CREATE`, `GUILD_ROLE_DELETE` and `GUILD_ROLE_UPDATE` names are mapped to `roleCreate`, `roleDelete`, `roleUpdate`.

Known useful events include:

| Event | Payload | Notes |
| --- | --- | --- |
| `ready` | Discord READY data | Also sets `Client.user`. |
| `resumed` | Discord RESUMED data | Connection/session was resumed. |
| `messageCreate` | Message object | Includes `reply`, `edit`, `delete`, `react`. |
| `messageUpdate` | Message-like object | Some fields can be absent in partial Discord updates. |
| `messageDelete` | Raw deletion data | Usually has `id`, `channel_id`, possibly `guild_id`. |
| `interactionCreate` | Interaction object | Includes interaction response methods. |
| `guildCreate`, `guildDelete`, `guildUpdate` | Discord guild event data | Depends on intents. |
| `guildMemberAdd`, `guildMemberRemove` | Member data | Requires appropriate intents. |
| `guildMemberUpdate` | `oldMember, newMember` | Two parameters like Discord.js, old can be nil. |
| `guildMemberUpdateRaw` | `newMember` | One-argument compatibility alias. |
| `guildMemberRoleAdd`, `guildMemberRoleRemove` | `newMember, roleId` | Custom convenience events with known baseline. |
| `guildMemberNicknameUpdate` | `oldMember, newMember` | Custom convenience nickname event. |
| `userUpdate` | `oldUser, newUser` | Changes to user fields observed by Gateway. |
| `messageReactionAdd`, `messageReactionRemove` | Reaction data | Requires reaction intent. |
| `typingStart` | Typing event data | Requires typing intent. |
| `roleCreate`, `roleDelete`, `roleUpdate` | Role event data | Nonstandard shortcut names used by this module. |
| `error` | Error **string** | Connection and REST transport errors. |
| `debug` | Debug **string** | Trace output when `debug=true`. |
| `warn` | Warning **string** if emitted | Listener can be registered; present transport does not normally emit a distinct warn event. |

Other Gateway dispatch event names are mapped in the same way, if Discord sends them and the chosen intents include them. Not every event is guaranteed to have a dedicated Lua wrapper; non-message and non-interaction events generally return Lua tables converted from Discord JSON.

```lua
Bot:on("error", function(err)
    outputDebugString("Discord error: " .. tostring(err), 1)
end)

Bot:on("messageDelete", function(data)
    outputDebugString("Deleted Discord message ID: " .. tostring(data.id))
end)
```

## 5. Sending and editing channel messages

### `Client:send(channelId, payload)`

Sends a message with Discord `POST /channels/{channelId}/messages`.

Arguments:

1. `channelId`: Discord channel ID as a string.
2. `payload`: string shorthand, or a table using Discord's message JSON fields.

Returns a Promise object when queued, or `nil, errorMessage` on immediate validation/queue error. A successful Promise `:next()` callback receives a **native message object** that includes `:reply`, `:edit`, `:delete` and `:react`.

```lua
Bot:send("123456789012345678", "Hello from MTA!")

Bot:send("123456789012345678", {
    content = "Server is online",
    embeds = {{title = "Server status", description = "Ready", color = 5763719}}
}):next(function(sentMessage)
    sentMessage:edit("Server is now ready")
end):catch(function(err)
    outputDebugString("Send failed: " .. tostring(err.message), 1)
end)
```

**Important:** If the first call returns `nil, errorMessage`, calling `:next()` on that `nil` is an error. Use the safe request pattern shown later for production code.

### `Client:editMessage(channelId, messageId, payload)`

Edits a message using Discord PATCH. All IDs are strings. Returns a Promise whose successful result is a native message object when Discord supplies the expected message data.

```lua
Bot:editMessage(CHANNEL_ID, MESSAGE_ID, {content = "Edited text"})
```

The bot usually may edit **its own messages**, not messages authored by somebody else.

## 6. Discord message object

The `messageCreate` and `messageUpdate` handlers receive a Lua table with Discord message fields plus module methods. Successful send/reply/edit operations also produce a message object.

Common fields are:

| Field | Type | Meaning |
| --- | --- | --- |
| `message.id` | string | Discord message snowflake. |
| `message.channel_id` | string | Discord channel ID. |
| `message.channelId` | string | Alias for `channel_id`. |
| `message.guild_id` | string or nil | Guild ID when available. |
| `message.guildId` | string or nil | Alias for `guild_id`. |
| `message.content` | string or nil | Text content, subject to Message Content intent. |
| `message.author` | table or nil | Author object: `id`, `username`, `bot`, etc. |
| `message.embeds` | Lua table or nil | Embeds included by Discord. |
| `message.attachments` | Lua table or nil | Attachment metadata if present. |
| `message.components` | Lua table or nil | Message components where provided. |
| `message.timestamp` | string or nil | Discord timestamp. |

Fields are not guaranteed for every Gateway payload; especially message updates can be partial. Treat optional fields carefully.

### `message:reply(payload)`

Sends a reply referencing the original message. Adds a `message_reference` automatically and sets `allowed_mentions.replied_user = false`, meaning the referenced user is not pinged by default.

```lua
message:reply("Pong!")
message:reply({embeds = {{title = "Response", color = 65280}}})
```

Returns a Promise or `nil, errorMessage`. The successful Promise value is a native message object.

### `message:edit(payload)`

Edits the message represented by this object. Best used for messages created by your bot, including the object returned by `:send()` or `:reply()`:

```lua
local pending, err = message:reply("Working...")
if pending then
    pending:next(function(sentMessage)
        sentMessage:edit("Finished!")
    end)
end
```

Trying to edit a message created by another user may return a Discord permission error.

### `message:delete()`

Requests message deletion. Returns a Promise. You can delete your own messages, and other messages when Discord allows the bot to do so.

```lua
message:delete():catch(function(err)
    outputDebugString("Delete failed: " .. tostring(err.message), 1)
end)
```

### `message:react(emoji)`

Adds a reaction to the given message via Discord REST.

```lua
message:react("👍")
message:react("name:123456789012345678")
```

Unicode emoji and Discord custom emoji strings can be passed. The module URL-encodes the value. Discord's permissions and emoji accessibility decide whether the request succeeds.

## 7. Promise objects and error handling

`Client:send`, `Client:editMessage`, `Client:request`, `Client:sendWebhook`, message methods, and interaction response methods return a **Promise-like Lua table** when the request is accepted into the native queue.

### `promise:next(successCallback[, errorCallback])`

Registers callback functions and returns the same Promise for chaining. On success, the callback gets either a native message object (send/reply/edit helpers) or a JSON-decoded Lua value (generic requests). The second optional callback receives an error table on failure.

### `promise:catch(errorCallback)`

Registers a failure callback and returns the Promise. Typical error fields:

- `err.message`: Discord error message or module error message, when available.
- `err.status`: HTTP status code for failed REST responses.
- Other Discord API error details may also be present.

Callbacks registered **after** the result was settled are invoked immediately with the already available result. Errors thrown inside a Lua callback are logged by the module, not automatically forwarded to `catch()`.

### Full request pattern

```lua
local function track(promise, immediateError)
    if not promise then
        outputDebugString("Discord queue error: " .. tostring(immediateError), 1)
        return
    end
    promise:next(function(result)
        outputDebugString("Discord request completed")
    end):catch(function(err)
        outputDebugString("Discord REST failed [" .. tostring(err.status) .. "]: " .. tostring(err.message), 1)
    end)
end

local p, err = Bot:send(CHANNEL_ID, "Hello")
track(p, err)
```

`promise.requestId` is an internal request sequence number, **not** a Discord message ID. The Promise also contains internal fields such as `__state` and `__result`. Prefer its methods instead of changing internal fields.

**Rate limits:** REST calls are queued. HTTP 429 responses are retried using Discord's retry information when possible, with limited retries. Avoid sending repeated announcements or hundreds of messages unnecessarily.

## 8. Embeds and advanced message payloads

`payload` tables use Discord API field names. The module converts the Lua table to JSON; it does not invent a different embed builder syntax.

### Text message

```lua
Bot:send(CHANNEL_ID, {content = "Hello"})
```

### Embed

```lua
Bot:send(CHANNEL_ID, {
    content = "Current status:",
    embeds = {{
        title = "MTA server",
        description = "Everything online",
        color = 5763719,
        url = "https://example.org",
        thumbnail = {url = "https://example.org/icon.png"},
        fields = {
            {name = "Players", value = "10/100", inline = true},
            {name = "Map", value = "Los Santos", inline = true}
        },
        footer = {text = "ml_discord by 1Lorenzo"},
        timestamp = "2026-11-01T20:00:00Z"
    }}
})
```

`color` is an integer RGB value, e.g. decimal `5763719`, not a CSS string such as `"#57F287"`. `fields` is an array of embed field objects.

### Buttons

```lua
Bot:send(CHANNEL_ID, {
    content = "Pick something:",
    components = {{
        type = 1,
        components = {
            {type = 2, style = 1, label = "Players", custom_id = "mta:players"},
            {type = 2, style = 2, label = "My ID", custom_id = "mta:myid"},
            {type = 2, style = 5, label = "Website", url = "https://example.org"}
        }
    }}
})
```

`type = 1` is an action row; `type = 2` is a button. For buttons, `style = 1` primary, `2` secondary, `3` success, `4` danger, `5` link. Non-link buttons use `custom_id` to identify clicks; link buttons use `url` and do not produce the same button interaction.

### Lua-to-JSON rules

- Lua strings, booleans and numbers become JSON scalar values.
- Sequential tables with numeric keys `1..N` become JSON arrays.
- Tables with string keys become JSON objects.
- An empty table serializes as `{}`; this implementation has no dedicated empty-JSON-array marker.
- JSON values must not contain cyclic references.
- Nested table conversion is limited to 24 levels.
- Non-finite numbers and unsupported Lua value types are rejected.
- Request bodies are limited to 256 KiB by the module, which may be stricter than Discord limits in some endpoints.
- The module passes raw Discord payloads, but does not provide a multipart upload interface for attaching local files.

If you provide dynamic user content, make sure mentions are properly controlled to avoid accidental pings.

## 9. Interaction and slash-command API

Discord sends `interactionCreate` for slash commands and buttons. The module exposes an interaction table with raw Discord fields plus convenience methods.

### Common interaction fields

| Field | Type | Meaning |
| --- | --- | --- |
| `interaction.id` | string | Interaction ID. |
| `interaction.token` | string | Callback token (treat it like a secret). |
| `interaction.type` | number | `2` application command, `3` message component, etc. |
| `interaction.data` | table or nil | Command or component data. |
| `interaction.customId` | string or nil | Alias for `data.custom_id`. |
| `interaction.commandName` | string or nil | Alias for `data.name`. |
| `interaction.user` | table or nil | User in DMs or other interaction contexts. |
| `interaction.member` | table or nil | Guild member data; use `member.user` for the user. |
| `interaction.channel_id` | string or nil | Channel where interaction happened. |
| `interaction.guild_id` | string or nil | Guild ID if present. |

The `customId` and `commandName` aliases are only added when their source field exists. Check `interaction.type` and the relevant data before using them.

### `interaction:reply(payload[, ephemeral])`

Sends interaction callback type `4`: a message response. `payload` can be a string or table. Set `ephemeral=true` to make it visible to the clicking user only (flag `64`).

```lua
interaction:reply("Only you can see this", true)
interaction:reply({embeds = {{title = "Command result", color = 3066993}}}, true)
```

### `interaction:defer([ephemeral])`

Sends callback type `5`: deferred channel message response. It acknowledges the interaction while more work is needed. It does **not** send the final visible result by itself; that requires an appropriate follow-up request in the Discord API.

### `interaction:deferUpdate()`

Sends callback type `6`: acknowledges a component update without immediately changing the message. Useful for buttons that should not send a new reply right now.

### `interaction:update(payload)`

Sends callback type `7`: updates the original component message in response to a button interaction.

```lua
if interaction.type == 3 and interaction.customId == "mta:refresh" then
    interaction:update({content = "Status refreshed"})
end
```

Use **one** initial response per interaction (`reply`, `defer`, `deferUpdate` or `update`). The initial response must happen before Discord's interaction deadline. These methods all return a Promise or `nil, errorMessage` when validation fails immediately.

### Registering slash commands

This version does not have a dedicated `registerSlashCommand()` method. Register commands with the raw REST API:

```lua
local path = "/applications/" .. APPLICATION_ID .. "/guilds/" .. GUILD_ID .. "/commands"
Bot:request("POST", path, {
    name = "players",
    description = "Check current MTA players",
    type = 1
})
```

Guild command registration is useful while testing. After the command is registered in Discord, users can run `/players` and the module receives it through `interactionCreate`.

The bot application ID, guild ID, token, permissions and interaction payload must be valid. Register commands when needed, not on every server tick.

## 10. Changing activity and presence

### `Client:setActivity(text)`

Sets a **playing** activity with an `online` status. Returns `true` if the Gateway payload was queued, otherwise `false` or `nil, errorMessage` if not logged in.

```lua
Bot:setActivity("MTA:SA | 15 players")
```

### `Client:setPresence(options)`

Uses an options table or string:

```lua
Bot:setPresence({status = "idle", activity = "MTA:SA", type = "watching"})
Bot:setPresence({status = "dnd", activity = "the server", type = "playing"})
Bot:setPresence("MTA:SA")
```

| Option | Expected value | Details |
| --- | --- | --- |
| `status` | `online`, `idle`, `dnd`, `invisible` | Invalid values default to `online`. |
| `activity` | string | Activity name; empty string sends no activities. |
| `type` | `playing`, `streaming`, `listening`, `watching`, `competing` | Invalid values default to playing. |

This call queues a Gateway presence update; `true` does not guarantee Discord accepted and displayed it already. `setActivity()` and `setPresence()` are two names for the same native implementation with different practical usage.

## 11. Webhooks

### `Client:sendWebhook(webhookUrl, payload)`

Uses a Discord HTTPS webhook URL and sends a message without a normal channel ID.

```lua
Bot:sendWebhook("https://discord.com/api/webhooks/ID/TOKEN", {
    username = "MTA Server",
    content = "Server started",
    embeds = {{title = "Status", description = "Online"}}
})
```

The URL must start with `https://discord.com/api/webhooks/`, include a valid numeric ID and token, and fit the module's URL validation. Optional query strings are limited to `?wait=true` or `?wait=false`.

The module defaults to `?wait=true` so Discord can return the result. Unlike `Client:send`, a webhook response is a generic Lua JSON result, not a native message wrapper.

The alias `Client.webhooks:send(webhookUrl, payload)` does the same thing.

Webhook URLs contain credentials. Never paste them in public logs or commit real URLs to GitHub.

## 12. Raw Discord REST API

### `Client:request(method, path[, body])`

Issues a request to Discord API v10.

Supported HTTP methods: `GET`, `POST`, `PATCH`, `PUT`, `DELETE`. Case-insensitive method strings are normalized internally.

`path` starts at `/`, for example `/users/@me` or `/channels/CHANNEL_ID/messages`. The module prepends `/api/v10` automatically, so do **not** add `/api/v10` to a normal path.

```lua
Bot:request("GET", "/users/@me"):next(function(user)
    outputDebugString("Logged in as: " .. tostring(user.username))
end)

Bot:request("GET", "/channels/" .. CHANNEL_ID .. "/messages/" .. MESSAGE_ID)
```

`body` is an optional Lua table (not a pre-serialized JSON string). This is handy for unsupported Discord endpoints, command registration, or retrieving extra API data. Make sure you follow Discord's API requirements yourself.

**Restrictions:** The path must be relative, under 2048 characters, cannot contain a second leading slash (`//`), backslashes, CR/LF or an embedded `://` URL. This method does not allow calls to arbitrary external hosts.

Success values are JSON-decoded Lua data, not necessarily message objects; use `Client:send` and `Client:editMessage` when you need message methods on successful results.

## 13. Limits and lifecycle details

| Limit | Value / behavior |
| --- | --- |
| `maxQueue` per client | Default `4096`, range `128..32768`. |
| Event payload stored in queue | Max ~1 MiB per event. |
| Events drained per MTA pulse | Up to `120` per client. |
| Pending REST promises | Up to `1024` per client. |
| REST requests queued in worker | Up to `1024`. |
| JSON REST request body | 256 KiB. |
| JSON table nesting | 24 levels. |
| Discord IDs used in method arguments | Decimal strings, 1–25 digits. |

On queue saturation, some non-response events may be discarded to make room. A network or process restart can drop pending Lua promises. The module handles Gateway heartbeat, connection retry and session resumption, but this should not be treated as a persistent job queue or database.

## 14. Feature boundaries

- This is a **bot** API, not a user account/self-bot API.
- Only server-side MTA Lua can access the module directly.
- Message payloads and embeds use Discord's normal JSON shapes; this module is not a full Discord UI builder.
- The example uses buttons and slash commands, not a full implementation of all possible Discord interaction types.
- A `Client:request` result is raw JSON; only the dedicated send/edit/reply helpers wrap message results with methods.
- There is no built-in persistent storage, slash-command registration manager, message cache, or scheduler.
- Rate limiting and Discord permissions are still the Discord platform's rules.
- A binary may load on one Linux distribution and fail on another because of native runtime dependency versions.

For ready-to-run use, read [the complete example](../example/ml_discord_demo/server.lua) and [example guide](EXAMPLES.md).


## 15. Guild members, roles and user updates (v0.9.0)

These functions are **native C++ methods** on the regular `Client` object. No Lua wrapper is needed. For full argument tables, examples, cache rules, role permissions, and event callback signatures read [Members & Roles](MEMBERS_AND_ROLES.md).

| Method | Arguments | Promise success value |
| --- | --- | --- |
| `Client:addRole` | `(guildId, userId, roleId)` | `nil` for Discord HTTP 204 |
| `Client:giveRole` | `(guildId, userId, roleId)` | Same as addRole |
| `Client:removeRole` | `(guildId, userId, roleId)` | `nil` for Discord HTTP 204 |
| `Client:remRole` | `(guildId, userId, roleId)` | Same as removeRole |
| `Client:getMember` | `(guildId, userId)` | Member table with `guild_id`; seeds cache |
| `Client:getRoles` | `(guildId, userId)` | Array of member role ID strings; seeds cache |
| `Client:getRoles` | `(guildId)` | Array of full guild role objects |
| `Client:getGuildRoles` | `(guildId)` | Array of guild role objects |
| `Client:getUser` | `(userId)` | User table; seeds the user snapshot cache |

The native cache holds a bounded set of recent member and user snapshots per client. It does not automatically fetch the whole guild on login. Individual added/removed role events are only sent when both old and new role lists are available, which prevents false changes. An `unknown -> new` member transition triggers `guildMemberUpdate(nil, newMember)` but not role add/remove convenience events.

This update changes the signature of `guildMemberUpdate` from one argument to two. Existing Lua code expecting the current member in its first parameter should switch to `guildMemberUpdateRaw` or update the handler to `(oldMember, newMember)`.
