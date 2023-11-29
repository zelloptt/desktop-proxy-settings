class ProxySettings {
  constructor() {
    try {
      const binary = require('@mapbox/node-pre-gyp');
      const path = require('path');
      const binding_path = binary.find(path.resolve(path.join(__dirname, './package.json')));
      this.impl = require(binding_path);
    } catch (ex) {
      console.log('unable to initialize desktop-proxy-settings:' + ex);
    }
  }

  read(url) {
    if (!this.impl) {
      return undefined;
    }
    return this.impl.read(url);
  }

  dump(url) {
    if (!this.impl) {
      return undefined;
    }
    return this.impl.dump(url);
  }

  openSystemSettings() {
    if (process.platform === 'darwin') {
      if (!this.impl || !this.impl.openSystemSettings()) {
        const script = "/usr/bin/osascript -e 'tell application \"System Preferences\"' -e 'activate' \
					-e 'set current pane to pane \"com.apple.preference.network\"' \
					-e 'reveal anchor \"Proxies\" of pane \"com.apple.preference.network\"' -e 'end tell'";
        require('child_process').exec(script);
      }
    } else {
      if (parseInt(require('os').release().split(".")[0]) > 7) {
        require('child_process').exec('START "" "ms-settings:network-proxy"');
      } else {
        require('child_process').exec('rundll32.exe shell32.dll,Control_RunDLL inetcpl.cpl,,4');
      }
    }
  }
}

const proxySettings = new ProxySettings();
module.exports = proxySettings;