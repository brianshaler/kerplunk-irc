###
# IRC Server schema
###

module.exports = (mongoose, blogSettings) ->
  Schema = mongoose.Schema
  ObjectId = Schema.ObjectId

  IRCServerSchema = new Schema
    serverName:
      type: String
      required: true
      index:
        unique: true
    nick:
      type: String
      required: true
    channels: [String]
    notifications: {}
    createdAt:
      type: Date
      default: Date.now

  mongoose.model 'IRCServer', IRCServerSchema
