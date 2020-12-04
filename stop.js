const path = require("path");
const shell = require('child_process').spawnSync;

const proc = shell('bash', [path.join(__dirname, 'run.sh'), 'clean'], {stdio: 'inherit'});
process.exit(proc.status);
