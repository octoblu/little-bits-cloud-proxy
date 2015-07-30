class LittleBitsOptionsBuilder

  getDevices: (payload) =>
    device_id = payload.device_id
    uri = payload.url.replace /:device_id/g, device_id
    {uri: uri}

  build: (payload, credentials, callback=->) =>
    return callback new Error 'Missing Url' unless payload.url?

    defaultOptions =
      method: payload.method
      headers:
        accept: 'application/vnd.littlebits.v2+json'
      auth:
        bearer: clientSecret

    if payload.url == 'https://api-http.littlebitscloud.cc/devices/:device_id' && method == 'GET'
      @getDevices payload, (error, options) =>
        return callback null, _.defaults({}, options, defaultOptions)

    callback new Error 'Unrecognized Options'

module.exports = LittleBitsOptionsBuilder
