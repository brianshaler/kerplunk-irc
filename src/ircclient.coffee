_ = require 'lodash'
{EventEmitter} = require 'events'
levelup = require 'levelup'
irc = require 'irc'
Promise = require 'when'

Channel = require './channel'
Message = require './message'

dev = true

class IRCClient extends EventEmitter
  constructor: (@System, @serverName, @desiredNick, @savedChannels = []) ->
    @nick = @desiredNick
    @connecting = false
    @connected = false
    @lastPingSent = 0
    @lastPongReceived = 0
    @irc = null
    @channels = []
    @dbPath = "#{@System.baseDir}/cache/irc-#{@serverName}"

    @cleanInterval = setInterval =>
      @clean()
    , 5000
    @connect()

  connect: =>
    # console.log 'creating irc client'
    if !@db
      # console.log 'creating db', @serverName
      dbopt = valueEncoding: 'json'
      @db = levelup @dbPath, dbopt
    if dev
      return console.log "kerplunk-irc/lib/ircclient.coffee: TEMPORARILY DON'T CONNECT TO IRC"
    else
      console.log '****************'
      console.log "kerplunk-irc/lib/ircclient.coffee: CURRENTLY RECONNECTING TO IRC EVERY RESTART"
      console.log '****************'
    return if @irc? and (@connecting or @connected)
    unless @irc?
      console.log 'connecting irc'
      opt =
        userName: 'kerplunk'
        realName: "Relaying messages on behalf of #{@nick} via Kerplunk"
      @irc = new irc.Client @serverName, @nick, opt

    #@irc.send 'nickserv', 'identify kerplunktester'

    clearInterval @pingInterval
    @connecting = true
    @irc
    .on 'error', @onError
    .on 'pong', =>
      console.log 'received pong'
      @lastPongReceived = Date.now()
    .on 'registered', (data) =>
      console.log 'registered', data
      @nick = data.args[0] ? @nick
      @connected = true
      @connecting = false
      @lastPingSent = Date.now()
      @lastPongReceived = Date.now() + 60 * 1000
      @connectAll()
      @emit 'connected'
      clearInterval @pingInterval
      @pingInterval = setInterval =>
        unless @connected
          console.log 'not connected'
          clearInterval @pingInterval
          return
        now = Date.now()
        if @lastPongReceived < now - 2 * 60 * 1000
          console.log "should i just manually close the connection?"
          console.log "maybe it'll auto reconnect?"
          @irc.conn.end()
          setTimeout =>
            @irc.connect()
          , 1000
          clearInterval @pingInterval
          return
        if @lastPongReceived < now - 60 * 1000 and @lastPingSent < now - 20 * 1000
          console.log 'send ping'
          @irc.send 'PING', String now
          @lastPingSent = now
      , 10 * 1000

  connectAll: =>
    _.each @savedChannels, (channelName) =>
      @getOrCreateChannel(channelName).connect()
    return

  disconnect: =>
    console.log 'Disconnecting from IRC (DISCONNECT)'
    clearInterval @cleanInterval
    @cleanInterval = null
    if @connected or @connecting
      #_.each @channels, (channel) ->
      #  channel.disconnect()
      @irc.disconnect()
    if @db
      # race condition city!
      @db.close()
      @db = null

  saveMessage: (data) =>
    Promise.promise (resolve, reject) ->
      console.log "running #{@serverName}:irc.message.do"
      m = data.message.toDB()
      console.log 'saving message', data
      @db.put "m:#{channel.name}:#{m.t}", m, (err) ->
        return reject err if err
        resolve data

  addChannel: (channelName) =>
    channel = new Channel @, channelName
    @channels.push channel
    channel.on 'connected', =>
      @channels = _.filter @channels, (c) -> c.name != channel.name
      @channels.push channel
    channel.on 'disconnected', =>
      @channels = _.filter @channels, (c) -> c.name != channel.name
    channel.on 'message', (message) =>
      data =
        serverName: @serverName
        channelName: channelName
        message: message

      @System.do 'irc.message', data
      .catch (err) ->
        # shrug
        true
      .then =>
        @emit 'message', channelName, data.message

      #m = message.toDB()
      #@db.put "m:#{channel.name}:#{m.t}", m
      #@emit 'message', channelName, message
    channel

  getChannel: (channelName) =>
    _.find @channels, (channel) -> channel.name == channelName

  getOrCreateChannel: (channelName) =>
    channel = @getChannel channelName
    channel = @addChannel channelName unless channel
    channel

  joinChannel: (channelName) =>
    channel = @getOrCreateChannel channelName
    unless (_.find @savedChannels, (c) -> c == channelName)
      @savedChannels.push channelName
    channel.connect()

  leaveChannel: (channelName) =>
    channel = @getChannel channelName
    @savedChannels = _.filter @savedChannels, (c) -> c != channelName
    if channel
      channel.disconnect()

  onError: (err) =>
    console.log 'error'
    console.log err

  say: (channelName, messageText) =>
    @irc.say "##{channelName}", messageText
    channel = @getChannel channelName
    message = new Message @nick, messageText
    m = message.toDB()
    @db.put "m:#{channel.name}:#{m.t}", m
    @emit 'message', channelName, message

  action: (channelName, messageText) =>
    console.log 'action!', messageText
    @irc.action "##{channelName}", messageText
    channel = @getChannel channelName
    message = new Message @nick, messageText
    message.isAction = true
    m = message.toDB()
    console.log m
    @db.put "m:#{channel.name}:#{m.t}", m
    @emit 'message', channelName, message

  send: (channelName, args...) =>
    @irc.send.apply @irc, args

  getRecent: (channelName, next) =>
    results = []
    base = "m:#{channelName}"
    opt =
      start: "#{base}:#{Date.now()-24*60*60*1000}"
      end: "#{base};"
    stream = @db.createReadStream opt
    stream.on 'data', (data) =>
      results.push data.value
    stream.on 'end', =>
      next null, results

  clean: =>
    opt =
      start: 'm:'
      end: 'm;'
    @db.createKeyStream opt
    .on 'data', (key) =>
      segments = key.split(":")
      if segments.length == 3
        time = parseInt segments[2]
        if time < Date.now() + 5 * 1000 and time > @stale()
          return
      @db.del key
    .on 'end', =>
      return #console.log "Done cleaning"

  cleanChannel: (channel) =>
    console.log "cleanChannel #{roomName}"
    opt =
      start: "#{roomName}:"
      end: "#{roomName}:#{@stale()}"
    console.log opt
    @db.createKeyStream opt
    .on 'data', (key) =>
      console.log "stale key #{key}"
      @db.del key
    .on 'end', =>
      return #console.log "Done cleaning"

  stale: -> Date.now() - 86400*1000 #5 * 60 * 1000

module.exports = IRCClient
