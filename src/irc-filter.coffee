# highlight, notify, mention

buildRegExp = (search) ->
  startMatch = endMatch = '\\b'
  if '*' == search.charAt 0
    search = search.substring 1
    startMatch = ''
  if '*' == search.charAt search.length-1
    search = search.substring 0, search.length-2
    endMatch = ''
  new RegExp startMatch + search + endMatch, 'i'

checkNick = (serverNotifications, channelNotifications, nick, text) ->
  actions = []
  if buildRegExp(nick).test text
    # you're definitely mentioned, and we'll go ahead and highlight
    actions.push 'mention'
    actions.push 'highlight'
    # but continue in case `notify` or custom actions are set...

    # if you want to be notified if you're mentioned in any channel
    if serverNotifications?.nick?.length > 0
      for action in serverNotifications.nick.split ','
        actions.push action
    else
      console.log "no serverNotifications.nick actions"
    # if you want to be notified if you're mentioned only in this specific channel
    if channelNotifications?.nick?.length > 0
      for action in channelNotifications.nick.split ','
        actions.push action
    else
      console.log "no channelNotifications.nick actions"
  else
    console.log "#{nick} not found in `#{text}`"
  actions

checkKeywords = (serverNotifications, channelNotifications, text) ->
  actions = []
  # if one of your keywords for that server is in the message
  if serverNotifications?.keywords?
    for keyword, actionList of serverNotifications.keywords
      if buildRegExp(keyword).test text
        for action in actionList.split ','
          actions.push action
      else
        console.log "server: keyword `#{keyword}` (#{actionList}) not found in `#{text}`"
  else
    console.log "no keywords"
  # if one of your keywords for that channel is in the message
  if channelNotifications?.keywords?
    for keyword, actionList of channelNotifications.keywords
      if buildRegExp(keyword).test text
        for action in actionList.split ','
          actions.push action
      else
        console.log "channel: keyword `#{keyword}` (#{actionList}) not found in `#{text}`"
  else
    console.log "no keywords for this channel"
  actions

filter = (server, item, next) ->
  {serverName, channelName, message} = item
  text = message.message

  console.log 'checking message', serverName, channelName, text
  serverNotifications = server.notifications
  channelNotifications = serverNotifications?.channels?[channelName] ? null

  actions = []
  actions = actions.concat checkNick serverNotifications, channelNotifications, server.nick, text
  actions = actions.concat checkKeywords serverNotifications, channelNotifications, text
  for action in actions
    item.message[action] = true
  next null, item

module.exports = filter
