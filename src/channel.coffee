{EventEmitter} = require 'events'

IRCMessage = require './message'

class IRCChannel extends EventEmitter
  constructor: (@client, @name) ->
    console.log 'IRCChannel', @name
    @connected = false
    @connecting = false

    if @client.connected
      @onClientConnected()
    else
      @client.on 'connected', =>
        @onClientConnected()

    @on 'connected', =>
      @connected = true
      @connecting = false
      console.log "Just connected to #{@name}"
    @on 'disconnected', =>
      @connected = false
      @connecting = false
      console.log "Just disconnected from #{@name}"

  onClientConnected: =>
    @client.irc.on "join##{@name}", @onJoin
    @client.irc.on "kick##{@name}", @onKick
    @client.irc.on "message##{@name}", @onMessage
    @client.irc.on "action##{@name}", @onAction
    @client.irc.on "kill##{@name}", @onKill
    @client.irc.on "quit", @onQuit

    # Hack to get action#channel events..
    @client.irc.on "raw", (message) =>
      return unless message.command == 'PRIVMSG'
      return unless message.args?.length == 2
      return unless message.args[0] == "##{@name}"
      text = message.args[1]
      actionPrefix = "\u0001ACTION "
      #console.log text.substring(0, actionPrefix.length), actionPrefix
      return unless text.substring(0, actionPrefix.length) == actionPrefix
      text = text.replace actionPrefix, ''
      text = text.replace "\u0001", ''
      @client.irc.emit "action##{@name}", message.nick, text, message

  connect: =>
    unless !@client.connected or @connected or @connecting
      @connecting = true
      @client.irc.join "##{@name}"

  connect: =>
    unless !@client.connected or @connected or @connecting
      @connecting = true
      @client.irc.join "##{@name}"

  disconnect: =>
    @client.irc.part "##{@name}"
    @emit 'disconnected'

  onJoin: (nick, message) =>
    if nick == @client.nick
      @emit 'connected'
    else if nick == @client.desiredNick
      @client.irc.emit 'nick', @client.desiredNick
    console.log 'Channel.onJoin', nick, message
    @emit 'join', nick, message

  onKick: (nick, kickedBy, reason, message) =>
    if nick == @client.nick
      @emit 'disconnected'
    else if nick == @client.desiredNick
      @client.irc.emit 'nick', @client.desiredNick
    console.log 'onKick', nick, kickedBy, reason, message
    @emit 'onKick', nick, kickedBy, reason, message

  onKill: (nick, reason, channels, message) =>
    if nick == @client.nick
      @emit 'disconnected'
      console.log 'onKill', nick, reason, channels, message
      @emit 'onKill', nick, reason, channels, message
    else if nick == @client.desiredNick
      @client.irc.emit 'nick', @client.desiredNick

  onQuit: (nick, reason, channels, message) =>
    if nick == @client.nick
      @emit 'disconnected'
      console.log 'onQuit', nick, reason, channels, message
      @emit 'onQuit', nick, reason, channels, message
    else if nick == @client.desiredNick
      @client.irc.emit 'nick', @client.desiredNick

  onMessage: (nick, text, message) =>
    m = new IRCMessage nick, text
    console.log 'Channel.onMessage', nick, text, message
    @emit 'message', m

  onAction: (nick, text, message) =>
    #text = "/#{nick} #{text}"
    m = new IRCMessage nick, text
    m.isAction = true
    console.log 'Channel.onAction', nick, text, message
    @emit 'message', m

module.exports = IRCChannel
