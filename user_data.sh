#!/bin/bash
set -e

exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Starting deployment ==="

# Wait for system
sleep 10

# Update system
yum update -y
yum install -y curl wget git

# Install NVM
export HOME=/root
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Source NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node.js 16 (compatible with Amazon Linux 2)
nvm install 16
nvm use 16
nvm alias default 16

# Verify
node --version
npm --version

# Create app directory
mkdir -p /opt/app
cd /opt/app

# Create minimal package.json
cat > package.json << 'EOF'
{
  "name": "three-tier-app",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.2",
    "mysql2": "^3.6.2",
    "aws-sdk": "^2.1500.0",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1"
  }
}
EOF

# Install dependencies
npm install --production

# Create server.js with better error handling
cat > server.js << 'ENDSERVER'
require('dotenv').config();
const express = require('express');
const mysql = require('mysql2/promise');
const AWS = require('aws-sdk');
const cors = require('cors');
const path = require('path');

console.log('Starting server...');
console.log('DB_HOST:', process.env.DB_HOST);
console.log('DB_PORT:', process.env.DB_PORT);
console.log('DB_NAME:', process.env.DB_NAME);

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

const s3 = new AWS.S3({region: process.env.AWS_REGION||'eu-central-1'});
const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT||3306),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  connectionLimit: 5,
  waitForConnections: true,
  queueLimit: 0,
  enableKeepAlive: true,
  keepAliveInitialDelayMs: 0
});

let dbReady = false;

async function initDb() {
  console.log('Initializing database...');
  let retries = 0;
  while(retries < 30) {
    try {
      const conn = await pool.getConnection();
      await conn.execute('CREATE TABLE IF NOT EXISTS users(id INT AUTO_INCREMENT PRIMARY KEY,name VARCHAR(255) NOT NULL,email VARCHAR(255) UNIQUE,phone VARCHAR(20),address VARCHAR(500),created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)');
      conn.release();
      console.log('Database initialized successfully');
      dbReady = true;
      return;
    } catch(e) {
      retries++;
      console.log('Database connection attempt ' + retries + '/30 failed:', e.message);
      if(retries >= 30) throw e;
      await new Promise(r => setTimeout(r, 2000));
    }
  }
}

app.get('/health',(r,s)=>s.json({status:'healthy',db:dbReady}));
app.get('/api/users',async(r,s)=>{if(!dbReady)return s.status(503).json({error:'db not ready'});try{const c=await pool.getConnection();const[rows]=await c.execute('SELECT * FROM users');c.release();s.json(rows);}catch(e){console.error(e);s.status(500).json({error:e.message});}});
app.get('/api/users/:id',async(r,s)=>{if(!dbReady)return s.status(503).json({error:'db not ready'});try{const c=await pool.getConnection();const[rows]=await c.execute('SELECT * FROM users WHERE id=?',[r.params.id]);c.release();if(!rows.length)return s.status(404).json({error:'not found'});s.json(rows[0]);}catch(e){console.error(e);s.status(500).json({error:e.message});}});
app.post('/api/users',async(r,s)=>{if(!dbReady)return s.status(503).json({error:'db not ready'});const{name,email,phone,address}=r.body;if(!name||!email)return s.status(400).json({error:'required'});try{const c=await pool.getConnection();const[result]=await c.execute('INSERT INTO users(name,email,phone,address)VALUES(?,?,?,?)',[name,email,phone||null,address||null]);c.release();s.status(201).json({id:result.insertId,name,email,phone,address});}catch(e){console.error(e);s.status(500).json({error:e.message});}});
app.put('/api/users/:id',async(r,s)=>{if(!dbReady)return s.status(503).json({error:'db not ready'});const{name,email,phone,address}=r.body;try{const c=await pool.getConnection();await c.execute('UPDATE users SET name=?,email=?,phone=?,address=? WHERE id=?',[name,email,phone||null,address||null,r.params.id]);c.release();s.json({id:r.params.id,name,email,phone,address});}catch(e){console.error(e);s.status(500).json({error:e.message});}});
app.delete('/api/users/:id',async(r,s)=>{if(!dbReady)return s.status(503).json({error:'db not ready'});try{const c=await pool.getConnection();const[result]=await c.execute('DELETE FROM users WHERE id=?',[r.params.id]);c.release();if(!result.affectedRows)return s.status(404).json({error:'not found'});s.json({message:'deleted'});}catch(e){console.error(e);s.status(500).json({error:e.message});}});
app.get('/',(r,s)=>s.sendFile(path.join(__dirname,'public','index.html')));

const PORT=process.env.PORT||3000;
initDb().then(()=>{app.listen(PORT,()=>console.log('Server listening on port '+PORT));}).catch(e=>{console.error('Failed to initialize database:',e);process.exit(1);});
ENDSERVER

# Create public directory
mkdir -p public

# Create minimal index.html
cat > public/index.html << 'ENDHTML'
<!DOCTYPE html><html><head><meta charset=UTF-8><meta name=viewport content="width=device-width"><title>Three-Tier App</title><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:Arial;background:linear-gradient(135deg,#667eea,#764ba2);min-height:100vh;padding:20px}.container{max-width:1200px;margin:0 auto}header{text-align:center;color:#fff;margin-bottom:40px}h1{font-size:2.5em}h2{color:#667eea;margin:20px 0}form,#userList{background:#fff;padding:20px;border-radius:10px;margin:20px 0}input,textarea{width:100%;padding:10px;margin:5px 0;border:1px solid #ddd;border-radius:5px}button{background:#667eea;color:#fff;border:none;padding:10px 20px;border-radius:5px;cursor:pointer;width:100%}button:hover{background:#764ba2}.user-item{background:#f8f9fa;padding:15px;margin:10px 0;border-left:4px solid #667eea}.msg{padding:10px;margin:10px 0;border-radius:5px;display:none}.msg.success{background:#d4edda;color:#155724;display:block}.msg.error{background:#f8d7da;color:#721c24;display:block}.status{background:#fff;padding:20px;margin:20px 0;border-radius:10px}</style></head><body><div class=container><header><h1>AWS Three-Tier App</h1><p>User Management System</p></header><h2>Add User</h2><div id=msg class=msg></div><form id=form><input type=text id=name placeholder=Name required><input type=email id=email placeholder=Email required><input type=tel id=phone placeholder=Phone><textarea id=address placeholder=Address rows=3></textarea><button type=submit>Add User</button></form><h2>Users</h2><div id=userList></div><div class=status><div>Status: <strong id=status>Loading...</strong></div><div>Total: <strong id=count>0</strong></div></div></div><script>const API='/api';function msg(t,type){const e=document.getElementById('msg');e.textContent=t;e.className='msg '+type;setTimeout(()=>{e.className='msg'},5000)}async function load(){try{const r=await fetch(API+'/users');const d=await r.json();const h=d.map(u=>'<div class="user-item"><strong>'+u.name+'</strong><br>'+u.email+(u.phone?'<br>'+u.phone:'')+'<br><button onclick=del('+u.id+')>Delete</button></div>').join('');document.getElementById('userList').innerHTML=h||'<p>No users</p>';document.getElementById('count').textContent=d.length;document.getElementById('status').textContent='Connected';}catch(e){document.getElementById('status').textContent='Error'}}async function del(id){if(!confirm('Delete?'))return;try{await fetch(API+'/users/'+id,{method:'DELETE'});msg('Deleted!','success');load();}catch(e){msg('Error','error')}}document.getElementById('form').addEventListener('submit',async e=>{e.preventDefault();try{const r=await fetch(API+'/users',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({name:document.getElementById('name').value,email:document.getElementById('email').value,phone:document.getElementById('phone').value,address:document.getElementById('address').value})});if(r.ok){msg('Added!','success');document.getElementById('form').reset();load();}else msg('Error','error');}catch(e){msg('Error','error')}});load();setInterval(load,30000);</script></body></html>
ENDHTML

# Create .env file - extract hostname from endpoint
DB_ENDPOINT="${db_endpoint}"
DB_HOST="${DB_ENDPOINT%:*}"  # Remove port if present

cat > .env << ENDENV
NODE_ENV=production
PORT=3000
DB_HOST=$DB_HOST
DB_PORT=3306
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASSWORD=${db_password}
S3_BUCKET=${s3_bucket}
AWS_REGION=${region}
ENDENV

# Create startup wrapper script with better logging
cat > /opt/app/start.sh << 'ENDWRAPPER'
#!/bin/bash
set -x
exec 2>&1
export HOME=/root
export NVM_DIR="/root/.nvm"

echo "=== Starting Node.js application ==="
echo "Current user: $(whoami)"
echo "Working directory: $(pwd)"
echo "PATH: $PATH"

# Source NVM
if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
  echo "NVM sourced successfully"
else
  echo "ERROR: NVM script not found at $NVM_DIR/nvm.sh"
  exit 1
fi

# Check Node.js
echo "Node version: $(node --version)"
echo "NPM version: $(npm --version)"

# Check if .env exists
if [ -f /opt/app/.env ]; then
  echo ".env file found"
else
  echo "ERROR: .env file not found"
  exit 1
fi

# Check if node_modules exists
if [ -d /opt/app/node_modules ]; then
  echo "node_modules directory found"
else
  echo "ERROR: node_modules not found, installing..."
  cd /opt/app
  npm install --production
fi

# Check if server.js exists
if [ -f /opt/app/server.js ]; then
  echo "server.js found"
else
  echo "ERROR: server.js not found"
  exit 1
fi

echo "=== All checks passed, starting Node.js ==="
cd /opt/app
exec node server.js
ENDWRAPPER

chmod +x /opt/app/start.sh

# Create systemd service with proper output redirection
cat > /etc/systemd/system/app.service << ENDSVC
[Unit]
Description=Three-Tier App
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/app
EnvironmentFile=/opt/app/.env
ExecStart=/opt/app/start.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=app
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target
ENDSVC

# Enable and start service
systemctl daemon-reload
systemctl enable app

# Run diagnostics before starting
echo "=== Running diagnostics ==="
echo "Checking Node.js:"
/root/.nvm/versions/node/v16.*/bin/node --version
echo "Checking npm:"
/root/.nvm/versions/node/v16.*/bin/npm --version
echo "Checking .env:"
cat /opt/app/.env
echo "Checking server.js:"
head -5 /opt/app/server.js
echo "Checking node_modules:"
ls -la /opt/app/node_modules | head -20

echo "=== Starting service ==="
systemctl start app

sleep 10
echo "=== Service status ==="
systemctl status app

# Check logs
echo "=== Application logs ==="
journalctl -u app -n 100 -e

echo "=== DEPLOYMENT COMPLETE ===" >> /var/log/user-data.log