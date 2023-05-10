var exec = require("cordova/exec");

var KakaoCordovaSDK = {
  login: function (successCallback, errorCallback) {
    exec(successCallback, errorCallback, "KakaoCordovaSDKV2", "login", []);
  },

  sendLinkFeed: function (template, successCallback, errorCallback) {
    exec(successCallback, errorCallback, "KakaoCordovaSDKV2", "sendLinkFeed", [
      template,
    ]);
  },
};

module.exports = KakaoCordovaSDK;
