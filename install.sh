#!/bin/bash

# Ask for the domain name
read -p "Enter the domain to be served by Caddy: " domain

# Function to install Caddy
install_caddy() {
    echo "Installing Caddy..."
    apt install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    apt update
    apt install caddy
}

# Function to install HAProxy
install_haproxy() {
    echo "Installing HAProxy..."
    sudo apt update
    sudo apt install haproxy
}

# Check if Caddy is installed and running
if ! command -v caddy &> /dev/null; then
    install_caddy
fi

# Check if HAProxy is installed and running
if ! command -v haproxy &> /dev/null; then
    install_haproxy
fi

# Configure Caddy
echo "Configuring Caddy for $domain..."
cat <<EOF | sudo tee /etc/caddy/Caddyfile

{
    http_port 8080
    https_port 5003
}


$domain {
    
handle /sub/* {
    root * /var/www/textfiles/
    file_server
    uri strip_prefix /sub
}

handle /ssh/* {
    root * /var/ssh-users/
    file_server
    uri strip_prefix /ssh
}

  # You may want to add additional configurations here, 
  # like logging, error handling, etc.    

}
EOF

# Restart Caddy to apply changes
sudo systemctl restart caddy

# Configure HAProxy
echo "Configuring HAProxy..."
cat <<EOF | sudo tee /etc/haproxy/haproxy.cfg
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log global
    mode tcp
    option tcplog
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend https_in
    bind *:443
    mode tcp
    tcp-request inspect-delay 5s
    tcp-request content accept if { req_ssl_hello_type 1 }
    use_backend caddy_backend if { req_ssl_sni -i $domain }
    use_backend sing-box if { req_ssl_sni -i www.speedtest.net }

backend caddy_backend
    mode tcp
    server caddy_server 127.0.0.1:5003 check

backend sing-box
    mode tcp
    server localhost 127.0.0.1:5002 check
EOF

# Restart HAProxy to apply changes
sudo systemctl restart haproxy

echo "Configuration completed."
