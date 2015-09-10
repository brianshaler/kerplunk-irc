_ = require 'lodash'
{EventEmitter} = require 'events'

IRCServerSchema = require './models/IRCServer'

module.exports = (System) ->
  IRCServer = null
  servers = []
  cachedServers = {}

  events = new EventEmitter()

  init = ->
    IRCServer = System.registerModel 'IRCServer', IRCServerSchema

  getServer = (serverName, next) ->
    return next null, cachedServers[serverName] if cachedServers[serverName]?
    IRCServer.findOne {serverName: serverName}, (err, server) ->
      return next err if err
      cachedServers[serverName] = server
      return next null, server

  getServers = (next) ->
    IRCServer.find {}, (err, servers) ->
      return next err if err
      if servers?.length > 0
        for server in servers
          cachedServers[server.serverName] = server
      else
        servers = []
      return next null, servers

  addChannel = (serverName, channelName, next) ->
    getServer serverName, (err, server) ->
      return next err if err
      return next Error 'Not found' unless server
      server.channels = [] unless server.channels?.length > 0
      exists = _.find server.channels, (existingChannelName) -> existingChannelName == channelName
      return next() if exists
      server.channels.push channelName
      server.markModified 'channels'
      server.save (err) ->
        cachedServers[serverName] = null
        next err

  removeChannel = (serverName, channelName, next) ->
    getServer serverName, (err, server) ->
      return next err if err
      return next Error 'Not found' unless server
      server.channels = [] unless server.channels?.length > 0
      server.channels = _.filter server.channels, (existingChannelName) -> existingChannelName != channelName
      server.markModified 'channels'
      server.save (err) ->
        cachedServers[serverName] = null
        next err

  create = (req, res, next) ->
    {serverName, nick} = req.params
    getServer serverName, (err, server) ->
      return next err if err
      return next Error 'Server already exists' if server
      data =
        serverName: serverName
        nick: nick
        channels: []
      server = new IRCServer data
      server.save (err) ->
        cachedServers[serverName] = null
        return next err if err
        events.emit 'create', serverName, nick
        url = "/admin/irc/server/#{serverName}/edit"
        if req.params.format == 'json'
          res.send
            status: 'success'
            url: url
        else
          res.redirect url

  destroy = (req, res, next) ->
    serverName = req.params.serverName
    getServer serverName, (err, server) ->
      return next err if err
      return next Error "Server doesn't exist" unless server
      server.remove (err) ->
        return next err if err
        delete cachedServers[serverName]
        events.emit 'destroy', serverName
        res.redirect "/admin/irc"

  setup = (req, res, next) ->
    getServers (err, servers) ->
      throw err if err
      console.log 'servers', servers
      #getChannels
      opt =
        servers: servers
      res.render 'setup', opt

  setupServer = (req, res, next) ->
    getServer req.params.serverName, (err, server) ->
      return next err if err
      return next() unless server

      opt =
        server: server
        channels: server.channels

      if req.body?.notifications?
        console.log 'saving settings'
        settingsObj = {}
        try
          settingsObj = JSON.parse req.body.notifications
        catch ex
          console.error ex
        server.notifications = settingsObj
        server.markModified 'notifications'
        server.save (err) ->
          console.error err if err
          res.render 'setupServer', opt
      else
        res.render 'setupServer', opt

  show = (req, res, next) ->
    {serverName, channelName} = req.params
    getServer serverName, (err, server) ->
      return next err if err
      return next() unless server
      res.render 'show',
        serverName: serverName
        channelName: channelName
        nick: server.nick

  cachedServers: cachedServers
  events: events
  init: init
  getServer: getServer
  getServers: getServers
  addChannel: addChannel
  removeChannel: removeChannel
  create: create
  destroy: destroy
  setup: setup
  setupServer: setupServer
  show: show
