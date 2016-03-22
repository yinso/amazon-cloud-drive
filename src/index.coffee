express = require('express')
app = express()
url = require 'url'
opener = require 'opener'
{ EventEmitter } = require 'events'
request = require 'request'
debug = require('debug')('clouddrive')

class CloudDrive extends EventEmitter
  constructor: (options) ->
    if not (@ instanceof CloudDrive)
      return new CloudDrive options
    { username , clientID , clientSecret , scopes , callbackUrl } = options
    Object.defineProperties @,
      username:
        value: username
        writable: false
        enumerable: false
      clientID:
        value: clientID
        writable: false
        enumerable: false
      clientSecret:
        value: clientSecret
        writable: false
        enumerable: false
      scopes:
        value: scopes or [
          'clouddrive:read_all'
          'clouddrive:write'
        ]
        writable: false
        enumerable: false
      callbackUrl:
        value: callbackUrl or 'http://localhost:45002/cloud-drive-callback'
        writable: false
        enumerable: false
  authenticate: (cb) ->
    self = @
    self.redirect (err, res) ->
      if err
        cb err
      else
        self.getOAuthToken res, (err, result) ->
          if err
            cb err
          else
            cb null, result
  redirect: (cb) ->
    self = @
    callbackUri = url.parse self.callbackUrl
    app.get callbackUri.pathname, (req, res, next) ->
      if req.query.error # this errors.
        console.error 'aws.cloud-drive-callback:error', req.query
        res.status(400).json req.query
        cb req.query
      else
        console.log 'aws.cloud-drive-callback', req.query
        self.once 'authenticated', (result) ->
          res.json result
        self.once 'error', (err) ->
          res.status(400).json(err)
        cb null, req.query
    app.listen callbackUri.port
    amazonOAUri = url.parse "https://www.amazon.com/ap/oa"
    amazonOAUri.query =
      client_id: @clientID
      scope: @scopes.join(' ')
      response_type: 'code'
      redirect_uri: @callbackUrl
    console.log('amazon-oa.uri', amazonOAUri)
    opener url.format(amazonOAUri)
  authRefresh: (expiresSeconds) ->
    self = @
    if self.refreshID
      clearTimeout self.refreshID
    timeoutCallback = () ->
      self.refreshOAuthToken (err, res) ->
        if err
          self.emit('error', err)
        else
          self.emit('authenticated', res)
    self.refreshID = setTimeout timeoutCallback, (expiresSeconds - 1) * 1000
  refreshOAuthToken: (cb) ->
    self = @
    oAuthUrl = 'https://api.amazon.com/auth/o2/token'
    options =
      method: 'POST'
      url: oAuthUrl
      form:
        grant_type: 'refresh_token'
        refresh_token: self.refreshToken
        client_id: self.clientID
        client_secret: self.clientSecret
      json: true
    console.log('AuthClient.refreshToken', options)
    request options, (err, res, body) ->
      if err
        console.log('AuthClient.refreshToken:ERROR', err)
        cb err
      else if res.statusCode >= 400
        console.log('AuthClient.refreshToken:HTTP_ERROR', res.statusCode, res.body)
        cb res.body
      else
        self.accessToken = body.access_token
        self.refreshToken = body.refresh_token
        self.authRefresh body.expires_in
        cb null, body
  getOAuthToken: ({ code }, cb) ->
    self = @
    oAuthUrl = 'https://api.amazon.com/auth/o2/token'
    options =
      method: 'POST'
      url: oAuthUrl
      form:
        grant_type: 'authorization_code'
        code: code
        client_id: self.clientID
        client_secret: self.clientSecret
        redirect_uri: self.callbackUrl
      json: true
    console.log('AuthClient.getOAuthToken', options)
    request options, (err, res, body) ->
      if err
        console.log('AuthClient.getOAuthToken:ERROR', err)
        self.emit 'error', err
        cb err
      else if res.statusCode >= 400
        console.log('AuthClient.getOAuthToken:HTTP_ERROR', res.statusCode, res.body)
        self.emit 'error', body
        cb res.body
      else
        body.code = code
        self.code = code
        self.accessToken = body.access_token
        self.refreshToken = body.refresh_token
        self.emit 'authenticated', body
        self.authRefresh body.expires_in
        cb null, body

module.exports = CloudDrive
