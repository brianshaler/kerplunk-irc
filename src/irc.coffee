_ = require 'lodash'
path = require 'path'
Promise = require 'when'

IRCClient = require './ircclient'
Manage = require './manage'
Filter = require './irc-filter'

module.exports = (System) ->
  clients = {}
  ircSocket = null
  manage = Manage System

  preMessage = (item) ->
    console.log 'pre irc.message'
    server = manage.cachedServers[item.serverName]
    return item unless server
    Promise.promise (resolve, reject) ->
      Filter server, item, (err, filteredItem) ->
        return reject err if err
        if filteredItem.message.notify
          data =
            template: 'kerplunk-irc:notification'
          _.merge data, filteredItem
          notification =
            navUrls: ["/admin/irc/channel/#{filteredItem.serverName}/#{filteredItem.channelName}/show"]
            data: data
          #notification.text = "#{notification.data.nick} mentioned you in ##{channelName} \"#{notification.data.message}\""
          System.do 'notification.create', notification
        resolve filteredItem

  saveMessage = (item) ->
    clients[item.serverName].saveMessage item

  kill = ->
    console.log 'irc killing clients', Object.keys clients
    for serverName, client of clients
      console.log 'disconnect', serverName
      client.disconnect()
      delete clients[serverName]

  createClient = (serverName, nick, channels = []) ->
    client = clients[serverName]
    return client if client
    client = new IRCClient System, serverName, nick, channels
    client.on 'message', (channelName, message) ->
      ircSocket.emit 'message', serverName, channelName, message
    clients[serverName] = client
    client

  destroyClient = (serverName) ->
    client = clients[serverName]
    if client
      client.disconnect()
      delete clients[serverName]
    null

  joinRoomByName = (req, res, next) ->
    {serverName, channelName} = req.params
    console.log 'joinRoomByName', serverName, channelName
    manage.getServer serverName, (err, server) ->
      return next err if err
      unless server
        console.log 'no server', serverName
      return next() unless server

      client = clients[serverName]
      unless client?
        client = createClient serverName, server.nick, server.channels

      manage.addChannel serverName, channelName, (err) ->
        throw err if err
        client.joinChannel channelName
        setupNav()
        System.resetGlobals()
        url = "/admin/irc/channel/#{serverName}/#{channelName}/show"
        if req.params.format == 'json'
          res.send
            status: 'success'
            url: url
        else
          res.redirect url

  leaveRoomByName = (req, res, next) ->
    {serverName, channelName} = req.params
    manage.getServer serverName, (err, server) ->
      return next err if err
      if !server
        console.log "server #{serverName} doesn't exist"
      return next() unless server

      client = clients[serverName]
      if !client
        console.log "client #{serverName} doesn't exist", Object.keys clients
      return next() unless client?

      manage.removeChannel serverName, channelName, (err) ->
        throw err if err
        client.leaveChannel channelName
        setupNav()
        System.resetGlobals()
        res.redirect "/admin/irc/server/#{serverName}/edit"

  say = (serverName, channelName, message) ->
    client = clients[serverName]
    unless client?.nick
      console.log 'client not found'
      console.log serverName, channelName, message
      return false

    patterns = [
      new RegExp "^/#{client.nick} ", 'i'
      new RegExp "^/me ", 'i'
    ]

    isAction = false
    for pattern in patterns
      if pattern.test message
        isAction = true
        message = message.replace pattern, ''

    if !isAction and message.charAt(0) == '/'
      client.send.apply client, [channelName].concat message.substring(1).split ' '
      return

    if isAction
      client.action channelName, message
    else
      client.say channelName, message

  sendMessage = (req, res, next) ->
    {serverName, channelName, message} = req.params
    say serverName, channelName, message
    res.send 'sent'

  sendAction = (req, res, next) ->
    {serverName, channelName, message} = req.params
    client = clients[serverName]
    client.action channelName, message
    res.send 'sent'

  recent = (req, res, next) ->
    client = clients[req.params.serverName]
    return next() unless client?.getRecent?

    client.getRecent req.params.channelName, (err, results) ->
      results = _.map results, (result) ->
        result.since = Math.round((Date.now()-result.t)/1000)
        result
      res.send
        messages: results

  ping = (req, res, next) ->
    {serverName, channelName} = req.params
    nick = req.query.nick ? 'someguy'
    message = req.query.message ? 'this is a message'
    IRCMessage = require './message'
    msg = new IRCMessage nick, message
    notification =
      navUrls: ["/admin/irc/channel/#{serverName}/#{channelName}/show"]
      urgency: 3
      data:
        template: 'kerplunk-irc:notification'
        serverName: serverName
        channelName: channelName
        message: msg
    #notification.text = "#{notification.data.nick} mentioned you in ##{channelName} \"#{notification.data.message}\""
    notification.text = 'notification text'
    System.do 'notification.new', notification
    .then ->
      res.send notification
    .catch (err) ->
      res.next err

  pong = (req, res, next) ->
    {serverName, channelName} = req.params
    url = "/admin/irc/channel/#{serverName}/#{channelName}/show"
    System.do 'notification.read',
      url: url
    .then ->
      res.send url
    .catch (err) ->
      res.next err

  show = (req, res, next) ->
    url = "/admin/irc/channel/#{req.params.serverName}/#{req.params.channelName}/show"

    System.do 'notification.read',
      url: url
    .catch (err) ->
      console.log 'error while marking notification as read'
      console.log err.stack ? err
      true
    .then ->
      manage.show req, res, next


  # init nav
  setupNav = ->
    nav =
      Admin:
        IRC:
          Settings: '/admin/irc'
    for serverName, client of clients
      nav.IRC = {} unless nav.IRC
      nav.Admin.IRC[serverName] = "/admin/irc/server/#{serverName}/edit"
      nav.IRC[serverName] = {} unless nav.IRC[serverName]
      for channelName in client.savedChannels
        nav.IRC[serverName]["##{channelName}"] = "/admin/irc/channel/#{serverName}/#{channelName}/show"
    IRC.globals.public.nav = nav

  IRC =
    handlers:
      'manageCreate': manage.create
      'manageSetup': manage.setup
      'manageSetupServer': manage.setupServer
      'manageDestroy': manage.destroy
      'joinRoomByName': joinRoomByName
      'leaveRoomByName': leaveRoomByName
      'sendMessage': sendMessage
      'sendAction': sendAction
      'recent': recent
      'show': show
      'ping': ping
      'pong': pong

    routes:
      admin:
        '/admin/irc': 'manageSetup'
        '/admin/irc/create/:serverName/:nick': 'manageCreate'
        '/admin/irc/server/:serverName/edit': 'manageSetupServer'
        '/admin/irc/server/:serverName/destroy': 'manageDestroy'
        '/admin/irc/channel/:serverName/:channelName/join': 'joinRoomByName'
        '/admin/irc/channel/:serverName/:channelName/leave': 'leaveRoomByName'
        '/admin/irc/channel/:serverName/:channelName/say/:message': 'sendMessage'
        '/admin/irc/channel/:serverName/:channelName/action/:message': 'sendAction'
        '/admin/irc/channel/:serverName/:channelName/recent': 'recent'
        '/admin/irc/channel/:serverName/:channelName/show': 'show'
        '/admin/irc/channel/:serverName/:channelName/ping': 'ping'
        '/admin/irc/channel/:serverName/:channelName/pong': 'pong'

    globals:
      public:
        irc:
          messageListComponent: 'kerplunk-irc:ircMessages'
          messageComponent: 'kerplunk-irc:ircMessage'
        css:
          'kerplunk-irc:show': 'kerplunk-irc/css/irc.css'
          'kerplunk-irc:notification': 'kerplunk-irc/css/irc.css'
          'kerplunk-irc:setup': 'kerplunk-irc/css/irc.css'
          'kerplunk-irc:setupServer': 'kerplunk-irc/css/irc.css'
    events:
      irc:
        message:
          pre: preMessage
          do: saveMessage

    methods:
      say: say

    kill: kill

    init: (next) ->
      manage.init()

      manage.events.on 'create', (serverName, nick) ->
        console.log "created", serverName, nick
        createClient serverName, nick
        #console.log clients
        setupNav()
        System.resetGlobals()
      manage.events.on 'destroy', (serverName) ->
        console.log "destroyed", serverName
        destroyClient serverName
        #console.log clients
        setupNav()
        System.resetGlobals()

      ircSocket = System.getSocket 'kerplunk-irc'
      ircSocket.on 'connection', (spark) ->
        onMessage = (serverName, channelName, message) ->
          if serverName == spark.query.serverName and channelName == spark.query.channelName
            spark.write message.toDB()
        ircSocket.on 'message', onMessage

        spark.on 'data', (data) ->
          console.log 'data', data, spark.query
          client = clients[spark.query.serverName]
          unless client?.channels?.length > 0
            console.log 'client not found?'
            console.log Object.keys clients
            console.log client?.channels
            console.log spark.query
            console.log data
          return unless client and client.channels?.length
          channel = client.getChannel spark.query.channelName
          unless channel?
            console.log 'channel not recognized?'
            console.log spark.query
            console.log data
          return unless channel?

          #console.log 'process socket data', data
          if data.message
            console.log 'say', spark.query.serverName, spark.query.channelName, data.message
            say spark.query.serverName, spark.query.channelName, data.message
            #client.say spark.query.channelName, data.message
          if data.read
            url = "/admin/irc/channel/#{spark.query.serverName}/#{spark.query.channelName}/show"
            System.do 'notification.read',
              url: url

        spark.on 'end', ->
          ircSocket.removeListener 'message', onMessage

      # create irc clients and add nav globals
      manage.getServers (err, servers) ->
        return next err if err
        for server in servers
          {serverName, nick, channels} = server
          createClient serverName, nick, channels
        setupNav()
        next()
