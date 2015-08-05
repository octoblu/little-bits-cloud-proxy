_ = require 'lodash'
request = require 'request'
MeshbluHttp = require 'meshblu-http'
debug = require('debug')('proxy-request-model')

class ProxyRequestModel
  constructor: (@meshbluConfig, @optionsBuilderClass) ->
    @meshbluHttp = new MeshbluHttp @meshbluConfig
    @privateKey = @meshbluHttp.setPrivateKey @meshbluConfig.privateKey

  buildRequestOptions: (payload, credentials, callback=->) =>
    debug 'buildRequestOptions', payload, credentials
    optionsBuilder = new @optionsBuilderClass
    optionsBuilder.build payload, credentials, (error, options) =>
      return callback error if error?

      callback null, options

  getCredentials: (uuid, callback=->) =>
    debug 'getCredentials', uuid
    @meshbluHttp.device uuid, (error, device) =>
      return callback error if error?
      callback null, @privateKey.decrypt(device.clientSecret, 'utf8')

  makeRequest: (options, callback=->) =>
    debug 'makeRequest', options
    request options, (error, response, body) ->
      return callback error if error?

      callback null, body

  sendMessage: (message, callback=->) =>

    @getCredentials message.fromUuid, (error, credentials) =>
      return callback error if error?

      @buildRequestOptions message?.payload, credentials, (error, options) =>
        return callback error if error?

        @makeRequest options, (error, body) =>
          return callback error if error?

          @sendMeshbluMessage message?.meshblu?.forwardedFor, body, (error, message) =>
            return callback error if error?

            callback null, message

  sendMeshbluMessage: (forwardedFor, body, callback) =>
    debug 'sendMeshbluMessage', forwardedFor, body
    message =
      devices: [_.first forwardedFor]
      forwardedFor: forwardedFor
      payload:
        body: body

    @meshbluHttp.message message, (error) ->
      return callback error if error?

      callback null, message

module.exports = ProxyRequestModel
