_ = require 'lodash'
React = require 'react'

{DOM} = React

module.exports = React.createFactory React.createClass
  getInitialState: ->
    contentHeight: 0
    availableHeight: 0

  componentDidMount: ->
    window.addEventListener 'resize', @handleResize
    @handleResize()

  componentWillUnmount: ->
    window.removeEventListener 'resize', @handleResize

  componentWillReceiveProps: (newProps) ->
    @handleResize newProps

  handleResize: (props = @props) ->
    content = @refs.messages.getDOMNode().offsetHeight
    available = window.innerHeight
    window.blah = @
    available -= @getDOMNode().offsetTop
    available -= @getDOMNode().offsetParent.offsetTop
    available -= props.inputHeight
    # height = window.innerHeight - @getDOMNode().offset().top
    # el.css
    #   height: height
    # messageContainer.css
    #   'max-height': height - input.height()
    @setState
      contentHeight: content
      availableHeight: available

  componentWillUpdate: ->
    node = @getDOMNode()
    @shouldScrollBottom = node.scrollTop + node.offsetHeight >= node.scrollHeight - 1

  componentDidUpdate: (prevProps, prevState) ->
    if @shouldScrollBottom
      node = this.getDOMNode()
      node.scrollTop = node.scrollHeight
    if @props.messages.length != prevProps.messages.length
      @handleResize()

  render: ->
    messageComponentPath = @props.globals.public.irc.messageComponent
    Message = @props.getComponent messageComponentPath

    DOM.div
      className: 'messages-container'
      style:
        overflowY: ('auto' if @state.contentHeight > @state.availableHeight)
        height: @state.availableHeight
    ,
      DOM.div
        ref: 'messages'
        className: 'messages'
      ,
        _.map @props.messages, (message) ->
          Message
            key: "message-#{message.t}-#{message.m}"
            message: message
