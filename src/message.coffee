
class IRCMessage
  @fromDB: (record) ->
    text = record.m ? record.a
    message = new IRCMessage record.u, text, new Date(record.t)
    if record.a
      message.isAction = true
      message.message = record.a
    if record.n
      message.notify = true
    if record.h
      message.highlight = true
    if record.at
      message.mention = true
    message
  
  constructor: (@nick, @message, @date = new Date()) ->
    @isAction = false
    @notify = false
    @highlight = false
    @mention = false
  #  @date = new Date @timestamp
  
  toDB: =>
    obj =
      u: @nick
      t: @date.getTime()
    if @isAction
      obj.a = @message
    else
      obj.m = @message
    if @notify
      obj.n = true
    if @highlight
      obj.h = true
    if @mention
      obj.at = true
    obj

module.exports = IRCMessage