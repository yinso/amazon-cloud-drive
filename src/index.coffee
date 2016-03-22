express = require('express')
app = express()
url = require 'url'
opener = require 'opener'
{ EventEmitter } = require 'events'
request = require 'request'

class CloudDrive
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
    callbackUri = url.parse @callbackUrl
    app.get callbackUri.pathname, (req, res, next) ->
      if req.query.error # this errors.
        console.error 'aws.cloud-drive-callback:error', req.query
        res.status(400).json req.query
        cb req.query
      else
        console.log 'aws.cloud-drive-callback', req.query
        res.json req.query
        self.getOAuthToken req.query, (err, result) ->
          if err
            cb err
          else
            cb null, result

    app.listen callbackUri.port
    amazonOAUri = url.parse "https://www.amazon.com/ap/oa"
    amazonOAUri.query =
      clien_id: @clientID
      scope: @scopes.join(' ')
      response_type: 'code'
      redirect_uri: @callbackUrl
    opener url.format(amazonOAUri)
  authRefresh: (expiresSeconds) ->
    self = @
    if self.refreshID
      clearTimeout self.refreshID
    self.refreshID = setTimeout () ->
      self.getOAuthToken { code: self.code }, (err, res) ->
        if err
          self.emit('error', err)
        else
          self.emit('authenticated', res)
  getOAuthToken: ({ code }, cb) ->
    self = @
    oAuthUrl = 'https://api.amazon.com/auth/o2/token'
    options =
      method: 'POST'
      url: oAuthUrl
      form:
        grant_type: 'authorization_code'
        code: code
        client_id: @clientID
        client_secret: @clientSecret
        redirect_uri: @callbackUri
      json: true
    request options, (err, res, body) ->
      if err
        cb err
      else if res.statusCode >= 400
        cb res.body
      else
        result.code = code
        self.code = code
        self.accessToken = result.access_token
        self.refreshToken = result.refresh_token
        self.authRefresh result.expires_in
        cb null, body

module.exports = CloudDrive
