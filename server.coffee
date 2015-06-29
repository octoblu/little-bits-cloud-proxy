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
OctobluStrategy = require 'passport-octoblu'
MeshbluHttp = require 'meshblu-http'
debug = require('debug')('little-bits-cloud-proxy')

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

meshbluOptions =
  server: meshbluConfig.server
  port: meshbluConfig.port

meshbluAuthorizer = meshbluAuth meshbluOptions

app.options '*', cors()

oauthProxyController = new OAuthProxyController meshbluConfig

octobluStrategyConfig =
  clientID: process.env.CLIENT_ID
  clientSecret: process.env.CLIENT_SECRET
  callbackURL: 'https://little-bits-cloud-proxy.octoblu.com/api/octoblu/callback'
  passReqToCallback: true

passport.use new OctobluStrategy octobluStrategyConfig, (req, token, secret, profile, next) ->
  debug 'got token', token, secret
  req.session.token = token
  next null, uuid: profile.uuid

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

  meshbluHttp = new MeshbluHttp uuid: process.env.CLIENT_ID, token: process.env.CLIENT_SECRET
  privateKey = meshbluHttp.setPrivateKey process.env.PRIVATE_KEY
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
  meshbluHttp = new MeshbluHttp uuid: process.env.CLIENT_ID, token: process.env.CLIENT_SECRET
  privateKey = meshbluHttp.setPrivateKey process.env.PRIVATE_KEY
  userUuid = req.user.uuid
  clientID = req.body.deviceId
  clientSecret = privateKey.encrypt req.body.token, 'base64'
  meshbluHttp.devices type: 'auth:little-bits-cloud-proxy', clientID: clientID, (error, result) =>
    device = _.first(result.devices)
    update =
      $set:
        clientSecret: clientSecret
      $addToSet:
        configureWhitelist: userUuid
        discoverWhitelist: userUuid

    if device
      meshbluHttp.updateDangerously device.uuid, update
    else
      meshbluHttp.register
        type: 'auth:little-bits-cloud-proxy'
        configureWhitelist: [octobluStrategyConfig.clientID]
        discoverWhitelist: [octobluStrategyConfig.clientID]
        clientID: clientID
        clientSecret: clientSecret
        meshblu:
          messageForward: [octobluStrategyConfig.clientID]
      , (error, device) ->
        meshbluHttp.register
          type: 'auth:user:little-bits-cloud-proxy'
          configureWhitelist: [userUuid]
          discoverWhitelist: [octobluStrategyConfig.clientID, userUuid]
          parentDevice: device.uuid
          meshblu:
            messageForward: [device.uuid]
        , (error, userDevice) ->
          meshbluHttp.update device.uuid, sendWhitelist: [userDevice.uuid]

app.get '/', passport.authenticate('octoblu')
app.get '/api/octoblu/callback', passport.authenticate('octoblu'), (req, res) ->
  res.redirect '/api/authorize'

server = app.listen PORT, ->
  host = server.address().address
  port = server.address().port

  console.log "Server running on #{host}:#{port}"
