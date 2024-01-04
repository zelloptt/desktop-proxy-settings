console.log("proxy-settings module started: ");

try {
	const ps = require('proxy-settings');
	console.log(ps.dump())
	ps.openSystemSettings();
} catch (ex) {
	console.log('exception ' + ex);
}
console.log('test finished...');
