_ = require 'lodash'
cors = require 'cors'
morgan = require 'morgan'
express = require 'express'
request = require 'request'
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

# app.use meshbluAuth meshbluOptions

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

app.post '/api/proxy', (req, res) ->
  clientId = req.body.clientId
  uri = req.body.uri
  qs  = req.body.qs
  method = req.body.method
  postBody = req.body.body ? false
  headers = req.body.headers ? {}
  signature = req.body.signature
  options  = req.body.options ? {}

  headers['accept'] = 'application/vnd.littlebits.v2+json'

  meshbluHttp = new MeshbluHttp uuid: process.env.CLIENT_ID, token: process.env.CLIENT_SECRET
  privateKey = meshbluHttp.setPrivateKey process.env.PRIVATE_KEY
  meshbluHttp.devices type: 'auth:little-bits-cloud-proxy', clientId: clientId, (error, result) =>
    device = _.first result.devices
    clientSecret = privateKey.decrypt device.clientSecret, 'utf8'

    _.extend options,
      uri: uri
      qs: qs
      method: method
      headers: headers
      json: postBody
      auth:
        bearer: clientSecret

    debug 'request', options
    request options, (error, response, body) ->
      res.status(422).send(error.message) if error?
      res.send(body)

app.get '/api/authorize', (req, res) ->
  res.sendFile 'index.html', root: __dirname + '/public'

app.post '/api/callback', (req, res) ->
  meshbluHttp = new MeshbluHttp uuid: process.env.CLIENT_ID, token: process.env.CLIENT_SECRET
  privateKey = meshbluHttp.setPrivateKey process.env.PRIVATE_KEY
  userUuid = req.user.uuid
  clientId = req.body.deviceId
  clientSecret = privateKey.encrypt req.body.token, 'base64'
  meshbluHttp.devices type: 'auth:little-bits-cloud-proxy', clientId: clientId, (error, result) =>
    device = _.first(result.devices)
    update =
      $set:
        clientSecret: clientSecret

    unless _.contains device.configureWhitelist, userUuid
      update.$push ?= {}
      update.$push.configureWhitelist = userUuid

    unless _.contains device.discoverWhitelist, userUuid
      update.$push ?= {}
      update.$push.discoverWhitelist = userUuid

    if device
      meshbluHttp.updateDangerously device.uuid, update
    else
      meshbluHttp.register
        type: 'auth:little-bits-cloud-proxy'
        configureWhitelist: [clientId, userUuid]
        discoverWhitelist: [clientId, userUuid]
        clientId: clientId
        clientSecret: clientSecret

app.get '/', passport.authenticate('octoblu')
app.get '/api/octoblu/callback', passport.authenticate('octoblu'), (req, res) ->
  res.redirect '/api/authorize'

server = app.listen PORT, ->
  host = server.address().address
  port = server.address().port

  console.log "Server running on #{host}:#{port}"
