_ = require 'lodash'

class LittleBitsOptionsBuilder
  allowedActions : [
    'getDevices'
    'sendEventToSubscribers'
    'getSubscriptions'
    'deleteSubscription'
    'createSubscription'
  ]

  getDevices: (payload, callback=->) =>
    options =
      method: 'GET'
      uri: "https://api-http.littlebitscloud.cc/devices/#{payload.device_id}"

    callback null, options

  sendEventToSubscribers: (payload, callback=->) =>
    options =
      method: 'POST'
      uri: "https://api-http.littlebitscloud.cc/devices/#{payload.device_id}/output"
      json:
        percent: payload.percent
        duration_ms: payload.duration_ms

    callback null, options

  getSubscriptions: (payload, callback=->) =>
    options =
      method: 'GET'
      uri: 'https://api-http.littlebitscloud.cc/subscriptions'
      qs:
        publisher_id: payload.publisher_id
        subscriber_id: payload.subscriber_id

    callback null, options

  deleteSubscription: (payload, callback=->) =>
    options =
      method: 'DELETE'
      uri: 'https://api-http.littlebitscloud.cc/subscriptions'
      qs:
        publisher_id: payload.publisher_id
        subscriber_id: payload.subscriber_id

    callback null, options

  createSubscription: (payload, callback=->) =>
    options =
      method: 'POST'
      uri: 'https://api-http.littlebitscloud.cc/subscriptions'
      json:
        publisher_id: payload.publisher_id
        subscriber_id: payload.subscriber_id
        publisher_events: payload.publisher_events

    callback null, options

  build: (payload, credentials, callback=->) =>
    subschema = payload.subschema
    return callback new Error 'Unrecognized Action' unless _.contains @allowedActions, subschema

    defaultOptions =
      headers:
        accept: 'application/vnd.littlebits.v2+json'
      auth:
        bearer: credentials

    #don't worry about it.
    @[subschema] payload[subschema], (error, options) =>
      return callback error if error?

      sendOptions = _.defaults {}, options, defaultOptions
      callback null, sendOptions

module.exports = LittleBitsOptionsBuilder
