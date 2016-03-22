#!/usr/bin/env node

var AuthClient = require('../lib/index');
var getenv = require('getenv');
var args = {
  username: getenv.string('USERNAME'),
  clientID: getenv.string('CLIENT_ID'),
  clientSecret: getenv.string('CLIENT_SECRET')
};

var auth = new AuthClient(args);

auth.authenticate(function (err, res) {
  console.log('cloud.drive.auth.result:', err, res);
});
