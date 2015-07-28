_ = require 'lodash'
cors = require 'cors'
async = require 'async'
morgan = require 'morgan'
express = require 'express'
request = require 'request'
NodeRSA = require 'node-rsa'
passport = require 'passport'
session = require 'cookie-session'
bodyParser = require 'body-parser'
errorHandler = require 'errorhandler'
meshbluAuth = require 'express-meshblu-auth'
MeshbluAuthExpress = require 'express-meshblu-auth/src/meshblu-auth-express'
meshbluHealthcheck = require 'express-meshblu-healthcheck'
OAuthProxyController = require './src/oauth-proxy-controller'
MeshbluConfig = require 'meshblu-config'
MeshbluHttp = require 'meshblu-http'
debug = require('debug')('little-bits-cloud-proxy')
CredentialDeviceManager = require './src/models/credential-device-manager'
UserCredentialDeviceManager = require './src/models/user-credential-device-manager'

meshbluConfig = new MeshbluConfig().toJSON()

PORT  = process.env.PORT || 80

passport.serializeUser (user, done) ->
  done null, JSON.stringify user

passport.deserializeUser (id, done) ->
  done null, JSON.parse id

app = express()
app.use cors()
app.use morgan('combined')
app.use errorHandler()
app.use meshbluHealthcheck()
app.use session cookie: {secure: true}, secret: 'totally secret', name: 'little-bits-cloud-proxy'
app.use passport.initialize()
app.use passport.session()
app.use bodyParser.urlencoded limit: '50mb', extended : true
app.use bodyParser.json limit : '50mb'
app.options '*', cors()

meshbluAuthorizer = meshbluAuth
  server: meshbluConfig.server
  port: meshbluConfig.port

app.post '/api/proxy', meshbluAuthorizer, (req, res) ->
  payload = req.body.payload
  parentDevice = payload.parentDevice
  uri = payload.uri
  qs  = payload.qs
  method = payload.method
  postBody = payload.body ? false
  headers = payload.headers ? {}
  signature = payload.signature
  options  = payload.options ? {}
  respondTo = payload.respondTo
  responseParams = payload.responseParams ? {}
  json = payload.json

  headers['accept'] = 'application/vnd.littlebits.v2+json'

  meshbluHttp = new MeshbluHttp meshbluConfig
  privateKey = meshbluHttp.setPrivateKey meshbluConfig.privateKey
  meshbluHttp.device parentDevice, (error, device) =>
    return res.status(422).send(error.message) if error?
    clientSecret = privateKey.decrypt device.clientSecret, 'utf8'

    _.extend options,
      uri: uri
      qs: qs
      method: method
      headers: headers
      body: postBody
      json: json
      auth:
        bearer: clientSecret

    debug 'request', options
    request options, (error, response, body) ->
      return res.status(422).send(error.message) if error?
      res.send(body)
      message =
        devices: [respondTo]
        payload:
          body: body
          uri: uri
          qs: qs
          method: method
          responseParams: responseParams
      meshbluHttp.message message, (error) ->
        return res.status(500).send(error.message) if error?
        res.status(201).end()

app.get '/api/authorize', (req, res) ->
  res.sendFile 'index.html', root: __dirname + '/public'

app.post '/api/callback', (req, res) ->
  debug 'meshbluConfig', meshbluConfig
  meshbluHttp = new MeshbluHttp meshbluConfig
  privateKey = meshbluHttp.setPrivateKey meshbluConfig.privateKey
  userUuid = req.session.userUuid
  clientID = req.body.deviceId
  clientSecret = privateKey.encrypt req.body.token, 'base64'

  options =
    messageSchemaUrl: 'https://raw.githubusercontent.com/octoblu/little-bits-cloud-proxy/master/schemas/message-schema.json'
    formSchemaUrl: 'https://raw.githubusercontent.com/octoblu/little-bits-cloud-proxy/master/schemas/form-schema.json'
    logo: 'https://cdn.octoblu.com/icons/devices/little-bits-cloud.svg'
    name: 'littleBits Cloud'

  credentialDeviceManager = new CredentialDeviceManager _.extend {}, meshbluConfig, options, type: 'channel-credentials:little-bits-cloud'
  userCredentialDeviceManager = new UserCredentialDeviceManager _.extend {}, _.extend {}, meshbluConfig, options, type: 'device-credentials:little-bits-cloud'

  # verify credentials are OK!!!

  credentialDeviceManager.findOrCreate clientID, meshbluConfig.uuid, (error, device) =>
    return res.status(500).send message: 'Unable to find or create device' if error?

    userCredentialDeviceManager.findOrCreate device.uuid, userUuid, meshbluConfig.uuid, (error, userDevice) =>
      return res.status(500).send message: 'Unable to find or create device' if error?

      credentialDeviceManager.addUserDevice device.uuid, userDevice.uuid
      credentialDeviceManager.updateClientSecret device.uuid, clientSecret

      return res.redirect req.session.callbackUrl if req.session.callbackUrl?

      res.status(201).send uuid: userDevice.uuid

app.get '/', (req, res) ->
  res.status(422).send message: 'UUID is required'

app.get '/new/:uuid', (req, res) ->
  req.session.userUuid = req.params.uuid
  req.session.callbackUrl = req.query.callbackUrl
  debug 'callbackUrl', req.session.callbackUrl
  res.redirect '/api/authorize'

server = app.listen PORT, ->
  host = server.address().address
  port = server.address().port

  console.log "Server running on #{host}:#{port}"
