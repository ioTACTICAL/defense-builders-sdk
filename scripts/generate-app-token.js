#!/usr/bin/env node

/**
 * GitHub App Token Generator
 * Generates installation access tokens for GitHub App authentication
 * 
 * Usage: node generate-app-token.js <app-id> <installation-id> <private-key-path>
 */

const fs = require('fs');
const https = require('https');
const crypto = require('crypto');

function generateJWT(appId, privateKeyPath) {
    const privateKey = fs.readFileSync(privateKeyPath, 'utf8');
    const now = Math.floor(Date.now() / 1000);
    
    const payload = {
        iat: now - 60,  // Issued 60 seconds in the past
        exp: now + (10 * 60),  // Expires in 10 minutes
        iss: appId
    };
    
    const header = {
        alg: 'RS256',
        typ: 'JWT'
    };
    
    const encodedHeader = Buffer.from(JSON.stringify(header)).toString('base64url');
    const encodedPayload = Buffer.from(JSON.stringify(payload)).toString('base64url');
    
    const signature = crypto
        .createSign('RSA-SHA256')
        .update(`${encodedHeader}.${encodedPayload}`)
        .sign(privateKey, 'base64url');
    
    return `${encodedHeader}.${encodedPayload}.${signature}`;
}

async function getInstallationToken(appId, installationId, privateKeyPath) {
    const jwt = generateJWT(appId, privateKeyPath);
    
    const postData = JSON.stringify({});
    
    const options = {
        hostname: 'api.github.com',
        port: 443,
        path: `/app/installations/${installationId}/access_tokens`,
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${jwt}`,
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
            'User-Agent': 'Defense-Builders-SDK/1.0',
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(postData)
        }
    };
    
    return new Promise((resolve, reject) => {
        const req = https.request(options, (res) => {
            let data = '';
            
            res.on('data', (chunk) => {
                data += chunk;
            });
            
            res.on('end', () => {
                if (res.statusCode === 201) {
                    const response = JSON.parse(data);
                    resolve(response.token);
                } else {
                    reject(new Error(`HTTP ${res.statusCode}: ${data}`));
                }
            });
        });
        
        req.on('error', (err) => {
            reject(err);
        });
        
        req.write(postData);
        req.end();
    });
}

async function main() {
    const [appId, installationId, privateKeyPath] = process.argv.slice(2);
    
    if (!appId || !installationId || !privateKeyPath) {
        console.error('Usage: node generate-app-token.js <app-id> <installation-id> <private-key-path>');
        console.error('');
        console.error('Example:');
        console.error('  node generate-app-token.js 123456 987654 ./private-key.pem');
        process.exit(1);
    }
    
    if (!fs.existsSync(privateKeyPath)) {
        console.error(`Error: Private key file not found: ${privateKeyPath}`);
        process.exit(1);
    }
    
    try {
        console.log('Generating GitHub App installation access token...');
        const token = await getInstallationToken(appId, installationId, privateKeyPath);
        console.log('');
        console.log('✅ Token generated successfully!');
        console.log('');
        console.log('Add this token to your repository secrets:');
        console.log('');
        console.log(`GIST_TOKEN=${token}`);
        console.log('');
        console.log('⚠️  This token expires in 1 hour. For production use, implement automatic token refresh.');
        
    } catch (error) {
        console.error('❌ Error generating token:', error.message);
        process.exit(1);
    }
}

main();