# Examples — real usage patterns

The complete ready-to-edit bot is in [`example/ml_discord_demo/server.lua`](../example/ml_discord_demo/server.lua). It demonstrates Discord → MTA commands, MTA → Discord events, embeds, buttons, slash commands, message edits, reactions, raw REST and webhooks.

## A. Plain message

```lua
local pending, err = Bot:send(CHANNEL_ID, "MTA server has started!")
if not pending then outputDebugString(tostring(err), 1) end
```

## B. Server status embed

```lua
local count = #getElementsByType("player")
Bot:send(CHANNEL_ID, {
    embeds = {{
        title = "Live MTA status",
        color = 5763719,
        fields = {{name = "Players", value = tostring(count), inline = true}}
    }}
})
```

## C. Ping by editing the reply

```lua
Bot:on("messageCreate", function(message)
    if message.content ~= "!ping" then return end
    if message.author and message.author.bot then return end

    local started = getTickCount()
    local pending, err = message:reply("Calculating...")
    if not pending then
        outputDebugString(tostring(err), 1)
        return
    end
    pending:next(function(sentMessage)
        local elapsed = getTickCount() - started
        sentMessage:edit("Pong! " .. elapsed .. "ms")
    end)
end)
```

This measures how long it took to get the reply result back through Discord and MTA, plus callback scheduling. It is not a raw network ping.

## D. Button menu and ephemeral reply

```lua
Bot:send(CHANNEL_ID, {
    content = "Server actions",
    components = {{type = 1, components = {
        {type = 2, style = 1, label = "Players", custom_id = "mta:players"},
        {type = 2, style = 2, label = "My ID", custom_id = "mta:id"}
    }}}
})

Bot:on("interactionCreate", function(interaction)
    if interaction.type ~= 3 then return end
    if interaction.customId == "mta:players" then
        interaction:reply("Players: " .. #getElementsByType("player"), true)
    elseif interaction.customId == "mta:id" then
        local user = interaction.member and interaction.member.user or interaction.user
        interaction:reply("Your ID: " .. tostring(user and user.id), true)
    end
end)
```

`true` makes that reply ephemeral. The user clicking the button can see it, other people cannot.

## E. Slash commands

To create a `/players` command in a test guild:

```lua
Bot:request("POST", "/applications/" .. APPLICATION_ID ..
    "/guilds/" .. GUILD_ID .. "/commands", {
        name = "players",
        description = "View online players",
        type = 1
    })
```

Then handle the interaction:

```lua
Bot:on("interactionCreate", function(interaction)
    if interaction.type == 2 and interaction.commandName == "players" then
        interaction:reply("Players: " .. #getElementsByType("player"), true)
    end
end)
```

## F. Change status

```lua
Bot:setPresence({status = "idle", activity = "the MTA server", type = "watching"})
Bot:setActivity("Los Santos")
```

## G. Fetch a message through raw REST

```lua
Bot:request("GET", "/channels/" .. CHANNEL_ID .. "/messages/" .. MESSAGE_ID)
    :next(function(data)
        outputDebugString("Message content: " .. tostring(data and data.content))
    end)
```

## H. Send a webhook announcement

```lua
Bot:sendWebhook(WEBHOOK_URL, {
    username = "MTA Status",
    content = "The server just started."
})
```

Webhooks need a private URL. They still use Discord REST and may be rate limited.

## I. MTA player joins → Discord channel

```lua
local connected = false
Bot:on("ready", function()
    connected = true
end)

addEventHandler("onPlayerJoin", root, function()
    if not connected then return end
    local playerName = getPlayerName(source):gsub("#%x%x%x%x%x%x", "")
    playerName = playerName:gsub("@", "@\226\128\139")
    Bot:send(CHANNEL_ID, "Player joined: " .. playerName)
end)
```

The example uses a small mention-safety replacement for player-supplied names. Be aware that relaying chat data into Discord also has privacy and moderation implications.

## J. Delete and react

```lua
message:react("✅")
message:delete()
```

Deletion permissions depend on which user owns the message and whether the bot has Manage Messages.

For a complete runnable resource, use the included `server.lua`, not every snippet here at the same time. Each snippet is meant to explain one piece of the API.


## Role management example (v0.9.0)

For full runnable role commands check [server.lua](../example/ml_discord_demo/server.lua). The following shows the custom role notification event:

```lua
Bot:on("guildMemberRoleRemove", function(member, roleId)
    outputDebugString("Removed role " .. tostring(roleId) ..
        " from " .. tostring(member.user and member.user.id))
end)
```

`guildMemberUpdate` now takes `oldMember, newMember` parameters. See [Members & Roles](MEMBERS_AND_ROLES.md) for cache behavior and all additional methods.
