_ = require 'lodash'

class CredentialDeviceManager
  constructor: (@options, dependencies={}) ->
    @type = @options.type
    @MeshbluHttp = dependencies.MeshbluHttp ? require 'meshblu-http'

  addUserDevice: (deviceUuid, userDeviceUuid, callback=->) =>
    meshbluHttp = new @MeshbluHttp @options
    meshbluHttp.updateDangerously deviceUuid, $addToSet: {sendWhitelist: userDeviceUuid}, callback

  create: (params, callback=->) =>
    options =
      type: @type
      messageSchemaUrl: ''
      logo: 'https://cdn.octoblu.com/icons/devices/little-bits-cloud.svg'
      owner: params.owner
      configureWhitelist: [params.owner]
      discoverWhitelist: [params.owner]
      clientID: params.clientID
      meshblu:
        messageForward: [params.owner]

    meshbluHttp = new @MeshbluHttp @options
    meshbluHttp.register options, (error, result) =>
      callback error, result

  findOrCreate: (clientID, owner, callback=->) =>
    meshbluHttp = new @MeshbluHttp @options
    meshbluHttp.devices type: @type, clientID: clientID, (error, result) =>
      return callback error if error? && error?.message != 'Devices not found'
      if _.isEmpty result?.devices
        return @create clientID: clientID, owner: owner, callback
      callback null, _.first result?.devices

  updateClientSecret: (deviceUuid, clientSecret, callback=->) =>
    meshbluHttp = new @MeshbluHttp @options
    meshbluHttp.update deviceUuid, clientSecret: clientSecret

module.exports = CredentialDeviceManager
