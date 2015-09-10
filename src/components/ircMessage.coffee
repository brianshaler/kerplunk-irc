React = require 'react'
moment = require 'moment'

{DOM} = React

module.exports = React.createFactory React.createClass
  getInitialState: ->
    {n, h, at} = @props.message

    highlighted: h or n or at

  render: ->
    classNames = ['irc-message']
    if @state.highlighted
      classNames.push 'irc-message-highlighted'
    timestamp = moment new Date @props.message.t
      .format 'h:mma'

    DOM.div
      className: classNames.join ' '
    ,
      DOM.div
        className: 'irc-message-timestamp'
      , timestamp
      if @props.message.a
        DOM.em
          className: 'irc-action'
        , "#{@props.message.u} #{@props.message.a}"
      else
        DOM.span null,
          DOM.strong
            className: 'irc-display-name'
          , @props.message.u
          DOM.span
            className: 'irc-message-body'
          , @props.message.m
