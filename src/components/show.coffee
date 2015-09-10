_ = require 'lodash'
React = require 'react'

{DOM} = React

module.exports = React.createFactory React.createClass
  getInitialState: ->
    draft: ''
    messages: if @props.messages instanceof Array
      @props.messages
    else
      []
    inputHeight: 0

  recent: ->
    url = "/admin/irc/channel/#{@props.serverName}/#{@props.channelName}/recent.json"
    @props.request.get url, {}, (err, data) =>
      return console.log 'error', err if err
      return console.log 'no messages', data unless data?.messages
      @addMessages data.messages

  addMessages: (newMessages) ->
    unless newMessages?.length > 0
      return console.log 'no messages?', newMessages
    newMessages = _.filter newMessages, (m1) =>
      existing = _.find @state.messages, (m2) ->
        m1.t == m2.t and m1.u == m2.u and (m1.m == m2.m or m1.a == m2.a)
      !existing
    unless newMessages.length > 0
      return console.log 'no new messages?', newMessages
    messages = _ @state.messages.concat(newMessages)
      .sortBy 't'
      .value()
    @setState
      messages: messages

  addMessage: (newMessage) ->
    @addMessages [newMessage]

  componentDidMount: ->
    @socket = @props.getSocket 'kerplunk-irc',
      serverName: @props.serverName
      channelName: @props.channelName
    @socket.on 'data', (data) =>
      # console.log 'data!', data
      if data.t
        @addMessage data
      else
        console.log "don't add", data
      #@setState
    @recent()
    @setState
      inputHeight: @refs.input.getDOMNode().offsetHeight

  updateMessage: (e) ->
    @setState
      draft: e.target.value

  onSend: (e) ->
    e.preventDefault()
    return unless @state.draft.length > 0
    console.log 'send', @state.draft
    @socket.write
      message: @state.draft
    @setState
      draft: ''

  render: ->
    messagesComponent = @props.globals.public.irc.messageListComponent
    Messages = @props.getComponent messagesComponent

    DOM.div
      className: 'irc-chat'
    ,
      DOM.div
        className: 'content'
      ,
        DOM.h3 null,
          DOM.a
            href: "/admin/irc/server/#{@props.serverName}/edit"
          , @props.serverName
          ": ##{@props.channelName}"
      Messages _.extend {}, @props,
        messages: @state.messages
        inputHeight: @state.inputHeight
      DOM.div
        ref: 'input'
        className: 'irc-message-input'
      ,
        DOM.form
          onSubmit: @onSend
        ,
          DOM.input
            ref: 'message'
            className: 'send-irc-message'
            onChange: @updateMessage
            value: @state.draft
            placeholder: 'type a message ...'
