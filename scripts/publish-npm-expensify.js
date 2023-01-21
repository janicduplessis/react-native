/**
 * @format
 */

'use strict';

const {exec, echo, exit, sed, rm} = require('shelljs');
const os = require('os');
const path = require('path');
const yargs = require('yargs');

const argv = yargs
  .option('base-version', {
    type: 'string',
  })
  .option('fork-version', {
    type: 'string',
  })
  .option('clean', {
    type: 'boolean',
    default: false,
  })
  .strict().argv;
const baseVersion = argv.baseVersion;
const forkVersion = argv.forkVersion;
const clean = argv.clean;

if (clean) {
  rm('-rf', path.join(__dirname, '../android'));
  rm('-rf', path.join(__dirname, '../sdks/download'));
  rm('-rf', path.join(__dirname, '../sdks/hermes'));
  rm('-rf', path.join(__dirname, '../sdks/hermesc'));
}

// Update the version number.
if (
  exec(
    `node scripts/set-rn-version.js --to-version ${forkVersion} --build-type release`,
  ).code
) {
  echo(`Failed to set version number to ${forkVersion}`);
  exit(1);
}

// Use the hermes prebuilt binaries from the base version.
sed(
  '-i',
  /^version = .*$/,
  `version = '${baseVersion}'`,
  path.join(__dirname, '../sdks/hermes-engine/hermes-engine.podspec'),
);

// Download hermesc from the base version.
const rnTmpDir = path.join(os.tmpdir(), 'hermesc');
const rnTgzOutput = path.join(rnTmpDir, `react-native-${baseVersion}.tgz`);
const hermescDest = path.join(__dirname, '../sdks');
exec(`mkdir -p ${rnTmpDir}`);
if (
  exec(
    `curl https://registry.npmjs.com/react-native/-/react-native-${baseVersion}.tgz --output ${rnTgzOutput}`,
  ).code
) {
  echo('Failed to download base react-native package');
  exit(1);
}
if (exec(`tar -xvf ${rnTgzOutput} -C ${rnTmpDir}`).code) {
  echo('Failed to extract base react-native package');
  exit(1);
}
exec(`mkdir -p ${hermescDest}`);
if (
  exec(`cp -r ${path.join(rnTmpDir, 'package/sdks/hermesc')} ${hermescDest}`)
    .code
) {
  echo('Failed to copy hermesc from base react-native package');
  exit(1);
}

// Build the android artifacts in the npm package.
if (exec('./gradlew publishAllInsideNpmPackage').code) {
  echo('Could not generate artifacts');
  exit(1);
}

// Generate tarball.
if (exec('npm pack').code) {
  echo('Failed to generate tarball');
  exit(1);
} else {
  exit(0);
}
