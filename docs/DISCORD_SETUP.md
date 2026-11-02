# Discord bot setup and permissions

## 1. Create the application

1. Go to https://discord.com/developers/applications.
2. Create a new application.
3. Open **Bot** and create/configure your bot.
4. Copy/reset your bot token and store it privately. Don't share it in screenshots, bug reports or public repositories.
5. Copy **Application ID** from General Information if you plan to register slash commands.

## 2. Privileged Gateway intents

In the **Bot** settings, enable the privileged intents actually used by your code. Prefix commands like `!ping` that inspect `message.content` typically require **Message Content Intent**. `GUILD_MEMBERS` and `GUILD_PRESENCES` are also privileged.

For the example resource:

```lua
local I = Discord.Intents
local Bot = Discord:Instance({
    intents = I.GUILDS + I.GUILD_MESSAGES + I.MESSAGE_CONTENT,
    debug = false
})
```

`4014` on Gateway connection usually indicates a disallowed intent. Either enable the required intent in the Discord Developer Portal or remove it from the Lua mask if you dont need it. Enabling everything is not recommended.

## 3. Invite the bot

Use the application's Installation/OAuth2 page to make an install link with `bot` and `applications.commands` scopes where appropriate. Give only permissions needed by your commands, commonly:

- View Channels
- Send Messages
- Read Message History
- Embed Links
- Add Reactions
- Use Application Commands (when relevant)
- Manage Messages only if your bot should delete other people's messages

Do not grant Administrator just to make a test bot work.

## 4. Find the IDs

Discord Developer Mode lets you copy server, channel and user IDs. Keep them as **quoted strings** in Lua, not numbers.

```lua
local CHANNEL_ID = "123456789012345678"
local GUILD_ID = "123456789012345678"
local OWNER_ID = "123456789012345678"
local APPLICATION_ID = "123456789012345678"
```

`OWNER_ID` is the Discord account allowed to use privileged commands in the example; it is not the bot application ID.

## 5. Invite the bot before testing

The bot must actually be present in the server and have permissions in the channel. Run `!ping` from a channel it can read; for slash commands use the `/` picker after registration.

## 6. Security notes

Bot tokens and webhook URLs act as credentials. Use placeholders in GitHub sources, and put the real values only in the private deployed copy of your resource. Reset the token if it was accidentally exposed. Avoid logging full Gateway payloads because interaction tokens can be included in them.

Useful docs:

- https://discord.com/developers/docs/topics/gateway#gateway-intents
- https://discord.com/developers/docs/interactions/receiving-and-responding
- https://discord.com/developers/docs/resources/message


## Member updates and role management

To receive `guildMemberUpdate` for other members, enable **Server Members Intent** in Discord Developer Portal and add `Discord.Intents.GUILD_MEMBERS` in the Lua bitmask. Role assignments need **Manage Roles** and valid bot role hierarchy. See [Members & Roles](MEMBERS_AND_ROLES.md).
