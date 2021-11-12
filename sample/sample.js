const ps = require('proxy-settings');

console.log("proxy-settings module started: ");

try {
	const d = ps.dump();
	const e = ps.enabled();
	const ps = ps.reload();

} catch (ex) {
	console.log('exception ' + ex);
}
console.log('test finished...');
