cors = require 'cors'
morgan = require 'morgan'
express = require 'express'
passport = require 'passport'
session = require 'express-session'
bodyParser = require 'body-parser'
errorHandler = require 'errorhandler'
meshbluAuth = require 'express-meshblu-auth'
MeshbluAuthExpress = require 'express-meshblu-auth/src/meshblu-auth-express'
meshbluHealthcheck = require 'express-meshblu-healthcheck'
OAuthProxyController = require './src/oauth-proxy-controller'
MeshbluConfig = require 'meshblu-config'
OctobluStrategy = require 'passport-octoblu'

meshbluConfig = new MeshbluConfig().toJSON()

PORT  = process.env.PORT || 80

passport.serializeUser (user, done) ->
  done null, JSON.stringify user

passport.deserializeUser (id, done) ->
  done err, JSON.parse id

app = express()
app.use cors()
app.use morgan('combined')
app.use errorHandler()
app.use meshbluHealthcheck()
app.use session cookie: {secure: true}, secret: 'totally secret'
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
  req.session.token = token
  console.log 'got token', token
  console.log 'got profile', profile
  next null, id: profile.uuid

app.get '/api/authorize', passport.authenticate('estimote-cloud')
app.get '/api/callback', passport.authenticate('estimote-cloud')
app.get '/', passport.authenticate('octoblu')
app.get '/api/octoblu/callback', passport.authenticate('octoblu'), (req, res) ->
  res.redirect '/api/authorize'

server = app.listen PORT, ->
  host = server.address().address
  port = server.address().port

  console.log "Server running on #{host}:#{port}"
