# Guild Members, Roles and Name Updates

**ml_discord v0.9.0 — 1Lorenzo — Windows x64 / Linux x64**

The module now exposes member and role APIs directly in native C++. It also compares cached member snapshots to report which role or nickname changed. The names `guildMemberUpdate` and `userUpdate` follow Discord.js style. `guildMemberRoleAdd`, `guildMemberRoleRemove` and `guildMemberNicknameUpdate` are **ml_discord convenience events**, not built-in discord.js events.

## Required intents and permissions

```lua
local I = Discord.Intents
local Bot = Discord:Instance({
    intents = I.GUILDS + I.GUILD_MEMBERS + I.GUILD_MESSAGES + I.MESSAGE_CONTENT
})
```

Enable **Server Members Intent** in Discord Developer Portal → Bot → Privileged Gateway Intents. The `GUILD_MEMBERS` bit is needed to receive member changes for other users. The bot also needs **Manage Roles** to change members' roles, with its highest role above the role being managed. `MESSAGE_CONTENT` is only necessary for reading regular prefix commands such as `!ping`, not for REST role operations.

**All Discord snowflake IDs must be decimal strings.** Do not pass Lua 5.1 numbers: large Discord IDs can lose precision.

## Assigning roles

`Client:addRole(guildId, userId, roleId)` uses Discord `PUT /guilds/{guild.id}/members/{user.id}/roles/{role.id}`. `Client:giveRole(...)` is an alias.

```lua
local request, err = Bot:addRole("123456789012345678", "234567890123456789", "345678901234567890")
if not request then
    outputDebugString(tostring(err), 1)
else
    request:next(function()
        outputDebugString("Role added")
    end):catch(function(e)
        outputDebugString("Role error HTTP " .. tostring(e.status) .. ": " .. tostring(e.message), 1)
    end)
end
```

Discord returns `204 No Content` for success, so the Promise succeeds without a response table. A failed REST call rejects the Promise. An immediate argument/queue failure returns `nil, errorText` before a Promise is created.

## Removing roles

`Client:removeRole(guildId, userId, roleId)` uses Discord `DELETE /guilds/{guild.id}/members/{user.id}/roles/{role.id}`. `Client:remRole(...)` is an alias.

```lua
Bot:removeRole(guildId, userId, roleId):next(function()
    outputDebugString("Role removed")
end):catch(function(err)
    outputDebugString(tostring(err.message), 1)
end)
```

Only chain `:next()` immediately when you know the call returned a Promise; otherwise handle `nil, errorText` as in the first example.

## Getting member information

`Client:getMember(guildId, userId)` returns a Promise resolving to the member object. It adds `guild_id` to the returned Lua table and keeps the member in a bounded native snapshot cache.

```lua
Bot:getMember(guildId, userId):next(function(member)
    outputDebugString("Username: " .. tostring(member.user and member.user.username))
    outputDebugString("Nickname: " .. tostring(member.nick))
    outputDebugString("Roles: " .. table.concat(member.roles or {}, ", "))
end)
```

## Getting a member's roles

`Client:getRoles(guildId, userId)` fetches the member and resolves with their **role ID strings**. It also seeds the member snapshot cache.

```lua
Bot:getRoles(guildId, userId):next(function(roleIds)
    for _, id in ipairs(roleIds) do
        outputDebugString("Role ID: " .. id)
    end
end)
```

This is not an array of complete role objects. It only includes roles assigned to that member (Discord's `@everyone` is not part of the `roles` array).

## Getting all roles on a guild

`Client:getGuildRoles(guildId)` or `Client:getRoles(guildId)` (one argument) resolves to an array of full role objects from Discord `GET /guilds/{guild.id}/roles`.

```lua
Bot:getGuildRoles(guildId):next(function(roles)
    for _, role in ipairs(roles) do
        outputDebugString(tostring(role.name) .. " | " .. tostring(role.id))
    end
end)
```

## Getting a Discord user

`Client:getUser(userId)` resolves to Discord user fields and seeds the user cache. Calling it does **not** subscribe you to every future update from that user.

```lua
Bot:getUser(userId):next(function(user)
    outputDebugString("Username: " .. tostring(user.username))
    outputDebugString("Display: " .. tostring(user.global_name))
end)
```

## Member updates, like discord.js

`guildMemberUpdate(oldMember, newMember)` now accepts **two** arguments. `oldMember` is `nil` if the member had no previous cached state. `newMember` contains the incoming updated state merged with any fields previously known.

```lua
Bot:on("guildMemberUpdate", function(oldMember, newMember)
    if not oldMember then return end
    outputDebugString("Member nick " .. tostring(oldMember.nick) ..
        " -> " .. tostring(newMember.nick))
end)
```

**Breaking change:** v0.8.2 used a single `member` argument for `guildMemberUpdate`. In v0.9.0, update that callback to `(oldMember, newMember)` or listen to `guildMemberUpdateRaw(newMember)` to keep the old one-argument behavior.

## Role added / removed events

```lua
Bot:on("guildMemberRoleAdd", function(member, roleId)
    outputDebugString("Added role " .. roleId .. " to " .. tostring(member.user.id))
end)

Bot:on("guildMemberRoleRemove", function(member, roleId)
    outputDebugString("Removed role " .. roleId .. " from " .. tostring(member.user.id))
end)
```

These convenience events are generated by comparing the **old cached role list** to the new list carried by `GUILD_MEMBER_UPDATE`. Each added/removed role gets its own callback. An uncached member does not produce fake add/remove events from the first update. The new member table and changed role ID string are provided to each callback.

To start watching one person right away, call `getMember` after ready:

```lua
Bot:on("ready", function()
    Bot:getMember("123456789012345678", "234567890123456789")
end)
```

The cache is bounded (up to 8192 member snapshots per client); it is not saved on disk, and it resets when the native client/resource restarts. Member add events and supplied guild member lists can populate it too.

## Nickname updates

```lua
Bot:on("guildMemberNicknameUpdate", function(oldMember, newMember)
    outputDebugString("Nickname: " .. tostring(oldMember.nick) ..
        " -> " .. tostring(newMember.nick))
end)
```

This watches the **guild nickname**, not the globally visible Discord account username. `oldMember` is guaranteed to exist for this convenience event.

## Discord username / display name updates

```lua
Bot:on("userUpdate", function(oldUser, newUser)
    local before = oldUser and (oldUser.global_name or oldUser.username) or "unknown"
    local after = newUser.global_name or newUser.username
    outputDebugString("User " .. tostring(newUser.id) .. ": " ..
        tostring(before) .. " -> " .. tostring(after))
end)
```

A `userUpdate` callback is emitted for changes the module can **observe**: `USER_UPDATE` Gateway messages and changed user information in `GUILD_MEMBER_UPDATE` packets. **Discord does not guarantee bots a Gateway event whenever any unrelated user changes their global username.** If guaranteed monitoring is essential, periodically fetch user details with `getUser` and compare the results in your own application. That polling is not automatic in this module.

## See updates inside MTA

The example Lua resource logs observed changes to `outputDebugString`, and can also show them in game chat using `outputChatBox`. Set `relayDiscordMemberChangesToGame = true` in its config to enable chat notifications. It will be visible to players; consider disabling it on public or busy servers.

## Common problems

- **No member events:** enable Server Members Intent in Developer Portal and in `Discord.Intents`.
- **No first role-add notification:** there was no old cached role list. Seed it using `getMember`.
- **HTTP 403:** check Manage Roles and the role hierarchy.
- **HTTP 404:** check guild, user and role IDs and whether they exist and are accessible.
- **Changing a global username produced nothing:** this is a Gateway coverage limitation; see above.
- **Wrong callback values:** use `(oldMember, newMember)` for `guildMemberUpdate`, not the old one-argument signature.

All the methods still use the same Promise style as other `ml_discord` REST operations.
