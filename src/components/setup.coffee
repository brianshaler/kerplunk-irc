_ = require 'lodash'
React = require 'react'

{DOM} = React

module.exports = React.createFactory React.createClass
  createServer: (e) ->
    e.preventDefault()
    serverName = @refs.newServerName.getDOMNode().value
    channelName = @refs.newChannelName.getDOMNode().value
    url = "/admin/irc/create/#{serverName}/#{channelName}.json"
    console.log 'post to', url
    @props.request.post url, {}, (err, data) ->
      return console.log err if err
      return console.log data unless data.status == 'success'
      window.location.href = data.url

  render: ->
    DOM.section
      className: 'content'
    ,
      DOM.h3 null, 'Setup'
      _.map @props.servers, (server, index) ->
        DOM.h4
          key: "server-#{index}"
        ,
          DOM.a
            href: "/admin/irc/server/#{server.serverName}/edit"
          , server.serverName
          ' '
          DOM.a
            href: "/admin/irc/server/#{server.serverName}/destroy"
          , '[x]'
      DOM.h4 null, 'Add new server'
      DOM.form
        onSubmit: @createServer
      ,
        DOM.input
          ref: 'newServerName'
          className: 'irc-serverName'
          name: 'irc-serverName'
          placeholder: 'server'
        DOM.input
          ref: 'newChannelName'
          className: 'irc-nick'
          name: 'irc-nick'
          placeholder: 'nick'
        DOM.button
          className: 'irc-add-server'
          onClick: @createServer
        , 'join'
