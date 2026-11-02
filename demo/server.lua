local Config = {
    token = "YOUR_BOT_TOKEN",
    commandChannelId = "YOUR_DISCORD_CHANNEL_ID",
    ownerId = "YOUR_DISCORD_USER_ID",
    guildId = "YOUR_DISCORD_GUILD_ID",
    watchedUserId = "",
    relayDiscordMemberChangesToGame = true,
    applicationId = "YOUR_DISCORD_APPLICATION_ID",
    webhookUrl = "",
    prefix = "!",
    relayPlayerJoins = false,
    relayPlayerChat = false,
    debug = false
}

local Intents = Discord.Intents
local Bot = Discord:Instance({
    intents = Intents.GUILDS + Intents.GUILD_MEMBERS + Intents.GUILD_MESSAGES + Intents.MESSAGE_CONTENT,
    debug = Config.debug,
    maxQueue = 4096
})

local ready = false

local function log(text, level)
    outputDebugString("[ml_discord_demo] " .. tostring(text), level or 3)
end

local function follow(promise, errorText, label)
    if not promise then
        log((label or "request") .. " could not be queued: " .. tostring(errorText), 1)
        return nil
    end
    promise:catch(function(err)
        log((label or "request") .. " failed (" .. tostring(err and err.status) .. "): " ..
            tostring(err and err.message or err), 1)
    end)
    return promise
end

local function send(channelId, payload, label)
    if not ready then return nil end
    local promise, err = Bot:send(channelId, payload)
    return follow(promise, err, label or "send")
end

local function playerCount()
    return #getElementsByType("player")
end

local function statusEmbed()
    return {
        title = "MTA:SA server status",
        description = "Live information from the MTA server",
        color = 5763719,
        fields = {
            {name = "Players online", value = tostring(playerCount()), inline = true},
            {name = "Server capacity", value = tostring(getMaxPlayers()), inline = true},
            {name = "Platform", value = "Multi Theft Auto: San Andreas", inline = false}
        },
        footer = {text = "ml_discord | 1Lorenzo"}
    }
end

local function nameForDiscord(text)
    text = tostring(text or "unknown"):gsub("#%x%x%x%x%x%x", "")
    text = text:gsub("@", "@\226\128\139")
    text = text:gsub("`", "'")
    return text:sub(1, 80)
end

local function sendButtons(channelId)
    send(channelId, {
        content = "MTA server controls",
        embeds = {statusEmbed()},
        components = {{
            type = 1,
            components = {
                {type = 2, style = 1, label = "Players", custom_id = "mta:players"},
                {type = 2, style = 3, label = "Hello", custom_id = "mta:hello"},
                {type = 2, style = 2, label = "My Discord ID", custom_id = "mta:myid"},
                {type = 2, style = 1, label = "Refresh menu", custom_id = "mta:refresh"}
            }
        }}
    }, "buttons")
end

local function showMemberChange(line)
    log(line)
    if Config.relayDiscordMemberChangesToGame then
        outputChatBox("[Discord] " .. line, root, 255, 200, 80, true)
    end
end

local function hasGuild()
    return Config.guildId ~= "" and Config.guildId ~= "YOUR_DISCORD_GUILD_ID"
end

local function isOwner(userId)
    return Config.ownerId ~= "YOUR_DISCORD_USER_ID" and tostring(userId) == Config.ownerId
end

local function registerPlayersSlash()
    if Config.applicationId == "YOUR_DISCORD_APPLICATION_ID" or
        Config.guildId == "YOUR_DISCORD_GUILD_ID" then
        return false
    end
    local path = "/applications/" .. Config.applicationId ..
        "/guilds/" .. Config.guildId .. "/commands"
    local promise, err = Bot:request("POST", path, {
        name = "players",
        description = "View current MTA players",
        type = 1
    })
    follow(promise, err, "register /players")
    return promise ~= nil
end

Bot:once("ready", function()
    log("First Discord READY received")
end)

Bot:on("ready", function()
    ready = true
    local username = Bot.user and Bot.user.username or "unknown"
    log("Discord bot connected: " .. username)
    Bot:setPresence({status = "online", activity = "MTA:SA", type = "playing"})
    if hasGuild() and Config.watchedUserId ~= "" then
        local pending, err = Bot:getMember(Config.guildId, Config.watchedUserId)
        follow(pending, err, "seed watched member")
    end
end)

Bot:on("resumed", function()
    ready = true
    log("Discord session resumed")
end)

Bot:on("messageCreate", function(message)
    if not message or (message.author and message.author.bot) then return end

    local content = message.content or ""
    local channelId = message.channel_id
    local authorId = message.author and message.author.id
    local prefix = Config.prefix

    if content == prefix .. "help" then
        follow(message:reply({
            embeds = {{
                title = "MTA Discord commands",
                color = 5763719,
                description = "`!ping` `!players` `!embed` `!buttons` `!react` `!fetch` " ..
                    "`!message` `!help` `!member USER_ID` `!roles USER_ID` " ..
                    "`!guildroles` `!user USER_ID`\nOwner: `!role add USER_ID ROLE_ID`, " ..
                    "`!role remove USER_ID ROLE_ID`, `!status online/idle/dnd/invisible`, " ..
                    "`!activity TEXT`, `!delete`, `!webhook`, `!registerslash`"
            }}
        }), nil, "help")

    elseif content == prefix .. "ping" then
        local started = getTickCount()
        local pending, err = message:reply("Measuring...")
        if not pending then
            log("Ping failed: " .. tostring(err), 1)
            return
        end
        pending:next(function(sentMessage)
            local elapsed = getTickCount() - started
            follow(sentMessage:edit("Pong! " .. tostring(elapsed) .. "ms"), nil, "ping edit")
        end):catch(function(e)
            log("Ping reply failed: " .. tostring(e and e.message), 1)
        end)

    elseif content == prefix .. "players" then
        follow(message:reply({embeds = {statusEmbed()}}), nil, "players")

    elseif content == prefix .. "embed" then
        send(channelId, {content = "Current server:", embeds = {statusEmbed()}}, "embed")

    elseif content == prefix .. "buttons" then
        sendButtons(channelId)

    elseif content == prefix .. "react" then
        follow(message:react("👍"), nil, "react")

    elseif content == prefix .. "fetch" then
        local path = "/channels/" .. channelId .. "/messages/" .. message.id
        local promise, err = Bot:request("GET", path)
        if promise then
            promise:next(function(data)
                log("Fetched message: " .. tostring(data and data.id))
            end)
        end
        follow(promise, err, "fetch")

    elseif content == prefix .. "message" then
        local promise = send(channelId, "A message written from native C++ module", "message")
        if promise then
            promise:next(function(sent)
                log("Sent bot message ID: " .. tostring(sent.id))
            end)
        end

    elseif content:match("^!member%s+%d+$") then
        local userId = content:match("^!member%s+(%d+)$")
        if not hasGuild() then
            follow(message:reply("Configure Config.guildId first"), nil, "missing guild")
            return
        end
        local pending, err = Bot:getMember(Config.guildId, userId)
        if pending then
            pending:next(function(member)
                local name = member.user and member.user.username or "unknown"
                local roleCount = #(member.roles or {})
                follow(message:reply("Member: " .. name .. " | Nick: " ..
                    tostring(member.nick) .. " | Roles: " .. tostring(roleCount)), nil, "member reply")
            end)
        end
        follow(pending, err, "getMember")

    elseif content:match("^!roles%s+%d+$") then
        local userId = content:match("^!roles%s+(%d+)$")
        if not hasGuild() then return end
        local pending, err = Bot:getRoles(Config.guildId, userId)
        if pending then pending:next(function(roles)
            local line = #roles == 0 and "None" or table.concat(roles, ", ")
            follow(message:reply("Roles for " .. userId .. ": " .. line:sub(1, 1500)), nil, "roles reply")
        end) end
        follow(pending, err, "getRoles")

    elseif content == "!guildroles" then
        if not hasGuild() then return end
        local pending, err = Bot:getGuildRoles(Config.guildId)
        if pending then pending:next(function(roles)
            local result = {}
            for _, role in ipairs(roles) do
                if #result >= 20 then break end
                result[#result + 1] = tostring(role.name) .. " (" .. tostring(role.id) .. ")"
            end
            follow(message:reply(table.concat(result, "\n"):sub(1, 1800)), nil, "guild roles reply")
        end) end
        follow(pending, err, "getGuildRoles")

    elseif content:match("^!user%s+%d+$") then
        local userId = content:match("^!user%s+(%d+)$")
        local pending, err = Bot:getUser(userId)
        if pending then pending:next(function(user)
            follow(message:reply("Discord user: " .. tostring(user.username) ..
                " | Display name: " .. tostring(user.global_name) ..
                " | ID: " .. tostring(user.id)), nil, "user reply")
        end) end
        follow(pending, err, "getUser")

    elseif content:match("^!role%s+%a+%s+%d+%s+%d+$") then
        if not isOwner(authorId) then return end
        if not hasGuild() then
            follow(message:reply("Configure Config.guildId first"), nil, "missing guild")
            return
        end
        local action, userId, roleId = content:match("^!role%s+(%a+)%s+(%d+)%s+(%d+)$")
        local pending, err
        if action == "add" then
            pending, err = Bot:addRole(Config.guildId, userId, roleId)
        elseif action == "remove" then
            pending, err = Bot:removeRole(Config.guildId, userId, roleId)
        else
            follow(message:reply("Use !role add or !role remove"), nil, "invalid role action")
            return
        end
        if pending then pending:next(function()
            follow(message:reply("Role " .. action .. " succeeded for " .. userId), nil, "role result")
        end) end
        follow(pending, err, "role " .. action)

    elseif content:sub(1, #prefix + 7) == prefix .. "status " and isOwner(authorId) then
        local state = content:sub(#prefix + 8)
        if state == "online" or state == "idle" or state == "dnd" or state == "invisible" then
            local ok = Bot:setPresence({status = state, activity = "MTA:SA", type = "playing"})
            follow(message:reply(ok and ("Presence: " .. state) or "Presence not queued"), nil, "status")
        else
            follow(message:reply("Options: online, idle, dnd, invisible"), nil, "status help")
        end

    elseif content:sub(1, #prefix + 9) == prefix .. "activity " and isOwner(authorId) then
        local activity = content:sub(#prefix + 10)
        local ok = Bot:setActivity(activity)
        follow(message:reply(ok and "Activity queued" or "Activity not queued"), nil, "activity")

    elseif content == prefix .. "delete" and isOwner(authorId) then
        follow(message:delete(), nil, "delete original message")

    elseif content == prefix .. "webhook" and isOwner(authorId) then
        if Config.webhookUrl ~= "" then
            local promise, err = Bot:sendWebhook(Config.webhookUrl, {
                username = "MTA Server",
                content = "Webhook demo sent from ml_discord",
                embeds = {statusEmbed()}
            })
            follow(promise, err, "webhook")
        else
            follow(message:reply("Set Config.webhookUrl first"), nil, "webhook help")
        end

    elseif content == prefix .. "registerslash" and isOwner(authorId) then
        follow(message:reply(registerPlayersSlash() and
            "Slash command registration queued" or "Set applicationId and guildId first"), nil, "slash registration")
    end
end)

Bot:on("interactionCreate", function(interaction)
    local user = (interaction.member and interaction.member.user) or interaction.user
    local userId = user and user.id or "unknown"
    local customId = interaction.customId or (interaction.data and interaction.data.custom_id)

    if interaction.type == 3 then
        if customId == "mta:hello" then
            follow(interaction:reply("Hello from MTA!", true), nil, "hello button")
        elseif customId == "mta:players" then
            follow(interaction:reply({embeds = {statusEmbed()}}, true), nil, "players button")
        elseif customId == "mta:myid" then
            follow(interaction:reply("Your Discord user ID is " .. tostring(userId), true), nil, "id button")
        elseif customId == "mta:refresh" then
            follow(interaction:update({
                content = "Server status updated",
                embeds = {statusEmbed()},
                components = {{type = 1, components = {
                    {type = 2, style = 1, label = "Players", custom_id = "mta:players"},
                    {type = 2, style = 3, label = "Hello", custom_id = "mta:hello"},
                    {type = 2, style = 2, label = "My Discord ID", custom_id = "mta:myid"},
                    {type = 2, style = 1, label = "Refresh menu", custom_id = "mta:refresh"}
                }}}
            }), nil, "refresh button")
        end
    elseif interaction.type == 2 and interaction.commandName == "players" then
        follow(interaction:reply({embeds = {statusEmbed()}}, true), nil, "/players")
    end
end)

Bot:on("guildMemberUpdate", function(oldMember, newMember)
    local userId = newMember and newMember.user and newMember.user.id or "unknown"
    if oldMember then
        log("Member update: " .. tostring(userId) ..
            " | old nick=" .. tostring(oldMember.nick) ..
            " | new nick=" .. tostring(newMember.nick))
    else
        log("Member update: " .. tostring(userId) .. " (no old snapshot available)")
    end
end)

Bot:on("guildMemberNicknameUpdate", function(oldMember, newMember)
    local userId = newMember.user and newMember.user.id or "unknown"
    showMemberChange("Nickname: " .. tostring(userId) .. " | " ..
        tostring(oldMember.nick) .. " -> " .. tostring(newMember.nick))
end)

Bot:on("guildMemberRoleAdd", function(member, roleId)
    local userId = member.user and member.user.id or "unknown"
    showMemberChange("Role added: user " .. tostring(userId) .. " | role " .. tostring(roleId))
end)

Bot:on("guildMemberRoleRemove", function(member, roleId)
    local userId = member.user and member.user.id or "unknown"
    showMemberChange("Role removed: user " .. tostring(userId) .. " | role " .. tostring(roleId))
end)

Bot:on("userUpdate", function(oldUser, newUser)
    local userId = newUser and newUser.id or "unknown"
    local oldName = oldUser and (oldUser.global_name or oldUser.username) or "unknown"
    local newName = newUser and (newUser.global_name or newUser.username) or "unknown"
    showMemberChange("User updated: " .. tostring(userId) .. " | " ..
        tostring(oldName) .. " -> " .. tostring(newName))
end)

Bot:on("messageDelete", function(data)
    log("Discord message deleted: " .. tostring(data and data.id))
end)

Bot:on("messageUpdate", function(data)
    if Config.debug then log("Discord message edited: " .. tostring(data and data.id)) end
end)

Bot:on("error", function(err)
    log("Discord transport error: " .. tostring(err), 1)
end)

Bot:on("debug", function(line)
    if Config.debug then log(line) end
end)

if Config.relayPlayerJoins then
    addEventHandler("onPlayerJoin", root, function()
        send(Config.commandChannelId, "Player joined: " .. nameForDiscord(getPlayerName(source)), "player join")
    end)

    addEventHandler("onPlayerQuit", root, function()
        send(Config.commandChannelId, "Player left: " .. nameForDiscord(getPlayerName(source)), "player quit")
    end)
end

if Config.relayPlayerChat then
    addEventHandler("onPlayerChat", root, function(text)
        send(Config.commandChannelId,
            "**" .. nameForDiscord(getPlayerName(source)) .. "**: " .. nameForDiscord(text),
            "player chat")
    end)
end

if Config.token == "YOUR_BOT_TOKEN" or Config.token == "" then
    log("Set Config.token in server.lua before starting the resource", 1)
else
    local ok, err = Bot:login(Config.token)
    if not ok then log("Bot login failed: " .. tostring(err), 1) end
end
