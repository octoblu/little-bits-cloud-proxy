_ = require 'lodash'

class LittleBitsOptionsBuilder

  getDevices: (payload, callback) =>
    uri = "https://api-http.littlebitscloud.cc/devices/#{payload.device_id}"
    callback null, uri: uri, method: 'GET'

  build: (payload, credentials, callback=->) =>
    return callback new Error 'Missing Url' unless payload.url?

    defaultOptions =
      headers:
        accept: 'application/vnd.littlebits.v2+json'
      auth:
        bearer: credentials

    if payload.action == 'getDevices'
      @getDevices payload, (error, options) =>
        return callback null, _.defaults({}, options, defaultOptions)

        callback new Error 'Unrecognized Options'

module.exports = LittleBitsOptionsBuilder
