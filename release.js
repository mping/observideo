#!/usr/bin/env node
/**
 * Release script for Node.js project
 * Usage: node release.js patch|minor|major
 */

const { execSync } = require('child_process');
const fs = require('fs');

const bumpType = process.argv[2];
if (!['patch', 'minor', 'major'].includes(bumpType)) {
  console.error('Usage: node release.js <patch|minor|major>');
  process.exit(1);
}

try {
  // 1. Bump version in package.json
  execSync(`npm version ${bumpType} -m "chore(release): bump version to %s"`, { stdio: 'inherit' });

  // 2. Get the new version
  const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
  const version = pkg.version;

  // 3. Push commit and tags
  execSync('git push', { stdio: 'inherit' });
  execSync('git push --tags', { stdio: 'inherit' });

  console.log(`✅ Release complete: v${version}`);
} catch (err) {
  console.error('❌ Release failed:', err);
  process.exit(1);
}