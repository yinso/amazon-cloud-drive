#!/usr/bin/env node

var CloudDrive = require('../lib/index');
var getenv = require('getenv');
var config = require('config')
var args = {
  username: getenv.string('USERNAME'),
  clientID: getenv.string('CLIENT_ID'),
  clientSecret: getenv.string('CLIENT_SECRET')
};

var client = new CloudDrive(args);

client.authenticate(function (err, res) {
  console.log('cloud.drive.auth.result:', err, res);
});
