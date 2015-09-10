React = require 'react'
moment = require 'moment'

{DOM} = React

module.exports = React.createFactory React.createClass
  render: ->
    {
      data
    } = @props.notification

    DOM.div
      className: 'notification-multiline'
    ,
      DOM.div
        className: 'notification-line1'
      ,
        'mentioned in '
        DOM.span
          null
        , "##{data.channelName}"
      DOM.div
        className: 'notification-line2'
      ,
        DOM.strong
          style:
            borderLeft: 'solid 0.3em rgba(0,0,0,0.08)'
            paddingLeft: '0.4em'
        ,
          data.message.nick
        ': '
        data.message.message
