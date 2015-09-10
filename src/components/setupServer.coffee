_ = require 'lodash'
React = require 'react'

{DOM} = React

module.exports = React.createFactory React.createClass
  joinChannel: (e) ->
    e.preventDefault()
    channelToJoin = @refs.channelToJoin.getDOMNode().value
    url = "/admin/irc/channel/#{@props.server.serverName}/#{channelToJoin}/join.json"
    @props.request.post url, {}, (err, data) ->
      return console.log err if err
      return console.log 'uh..', data unless data?.status == 'success'
      window.location.href = data.url
    console.log 'join channel', channelToJoin

  render: ->
    {server, channels} = @props

    DOM.section
      className: 'content'
    ,
      DOM.h3 null, "Setup #{server.serverName}"
      DOM.div null,
        _.map channels, (channelName) ->
          DOM.div null,
            DOM.div null,
              DOM.h3
                style:
                  display: 'inline'
              ,
                DOM.a
                  href: "/admin/irc/channel/#{server.serverName}/#{channelName}/show"
                , "##{channelName}"
            DOM.div
              className: 'channel-notification'
              style:
                padding: '0.8em 1.0em'
            ,
              DOM.h4 null, 'Channel Notifications'
              p null,
                DOM.input
                  type: 'checkbox'
                  name: 'server'
                  id: "chk-#{channelName}-nick"
                label
                  for: "chk-#{channelName}-nick"
                , 'mentions'
      DOM.h3 null, "Join channel"
      DOM.div
        className: 'irc-join-channel'
      ,
        DOM.form
          onSubmit: @joinChannel
        ,
          '#'
          DOM.input
            ref: 'channelToJoin'
            type: 'text'
            className: 'irc-channel-to-join'
            name: "new-#{server.serverName}"
            placeholder: 'channel'
          DOM.button
            className: 'irc-join-channel'
            onClick: @joinChannel
          , 'join'
