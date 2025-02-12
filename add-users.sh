#!/bin/bash

# Configuration
KEY_FILE="salman-dev.pem"
EC2_USER="ubuntu"
EC2_HOST="status.qolimpact.com"

# Check if key file exists
if [ ! -f "$KEY_FILE" ]; then
    echo "Error: Key file $KEY_FILE not found"
    exit 1
fi

# Ensure key file has correct permissions
chmod 600 "$KEY_FILE"

# Function to create user command
create_user_command() {
    local username=$1
    local password=$2
    
    cat << SSHCOMMAND
    set -e  # Exit on any error

    echo "Setting up Node.js environment..."
    mkdir -p /tmp/uptime-kuma-add-user
    cd /tmp/uptime-kuma-add-user

    echo "Creating Node.js script..."
    cat > add_user.js << 'NODESCRIPT'
const bcrypt = require('bcrypt');
const sqlite3 = require('sqlite3').verbose();

// Get command line arguments
const args = process.argv.slice(2);
const [username, password] = args;

if (!username || !password) {
    console.error('Usage: node script.js <username> <password>');
    process.exit(1);
}

console.log('Adding user:', username);

async function addUser() {
    try {
        const db = new sqlite3.Database('/app/data/kuma.db');
        
        // Use exact same bcrypt settings as the working user
        const hash = await bcrypt.hash(password, 10);
        console.log('Generated hash:', hash);
        
        // First check if user exists
        const row = await new Promise((resolve, reject) => {
            db.get('SELECT id FROM user WHERE username = ?', [username], (err, row) => {
                if (err) reject(err);
                else resolve(row);
            });
        });
            
        if (row) {
            // Update existing user
            await new Promise((resolve, reject) => {
                db.run('UPDATE user SET password = ? WHERE username = ?',
                    [hash, username],
                    (err) => {
                        if (err) reject(err);
                        else resolve();
                    }
                );
            });
            console.log('User password updated successfully');
        } else {
            // Create new user
            await new Promise((resolve, reject) => {
                db.run('INSERT INTO user (username, password, active) VALUES (?, ?, 1)',
                    [username, hash],
                    (err) => {
                        if (err) reject(err);
                        else resolve();
                    }
                );
            });
            console.log('User created successfully');
        }

        // Verify the user was created/updated
        const verifyRow = await new Promise((resolve, reject) => {
            db.get('SELECT username, password FROM user WHERE username = ?', [username], (err, row) => {
                if (err) reject(err);
                else resolve(row);
            });
        });
        console.log('Verified user in database:', verifyRow);
        
        db.close();
    } catch (err) {
        console.error('Error:', err);
        process.exit(1);
    }
}

addUser().catch(err => {
    console.error('Unhandled error:', err);
    process.exit(1);
});
NODESCRIPT

    echo "Installing dependencies..."
    cd /tmp/uptime-kuma-add-user
    sudo docker exec uptime-kuma npm install bcrypt@5.0.1 sqlite3
    
    echo "Updating Uptime Kuma..."
    sudo docker cp add_user.js uptime-kuma:/app/add_user.js
    
    echo "Executing database update..."
    sudo docker exec uptime-kuma node /app/add_user.js "${username}" "${password}"

    echo "Cleaning up..."
    cd /
    sudo rm -rf /tmp/uptime-kuma-add-user

    echo "User ${username} has been created/updated successfully"
    echo "----------------------------------------"
    echo "Next steps:"
    echo "1. Access Uptime Kuma at http://status.qolimpact.com:3001"
    echo "2. Log in with username: ${username} and your provided password"
    echo "----------------------------------------"
SSHCOMMAND
}

# Check if username is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <username> [password]"
    echo "Example: $0 mikedon mypassword123"
    echo "If password is not provided, a random one will be generated"
    exit 1
fi

# Get or generate password
USERNAME=$1
PASSWORD=${2:-$(openssl rand -base64 12)}

# Create and execute the remote command
echo "Creating user $USERNAME on $EC2_HOST..."
REMOTE_COMMAND=$(create_user_command "$USERNAME" "$PASSWORD")
ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_HOST" "$REMOTE_COMMAND"

# If password was generated, show it
if [ $# -eq 1 ]; then
    echo "Generated password for $USERNAME: $PASSWORD"
fi 