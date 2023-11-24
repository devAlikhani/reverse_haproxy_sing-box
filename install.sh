#!/bin/bash

# Function to install Caddy
install_caddy() {
    echo "Installing Caddy..."
    apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" | tee /etc/apt/sources.list.d/caddy-stable.list
    apt-get update
    apt-get install caddy
}

# Function to install HAProxy
install_haproxy() {
    echo "Installing HAProxy..."
    apt-get update
    apt-get install haproxy
}

# Function to configure Caddy and HAProxy
configure_caddy_haproxy() {
    # Configure Caddy
    echo "Configuring Caddy for $domain..."
    cat <<EOF | tee /etc/caddy/Caddyfile
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
}
EOF

    # Restart Caddy to apply changes
    systemctl restart caddy

    # Configure HAProxy
    echo "Configuring HAProxy..."
    cat <<EOF | tee /etc/haproxy/haproxy.cfg
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

backend caddy_backend
    mode tcp
    server caddy_server 127.0.0.1:5003 check
EOF

    # Restart HAProxy to apply changes
    systemctl restart haproxy
}

# Function to add a new service to HAProxy
add_service_to_haproxy() {
    read -p "Enter the port for the new service (e.g., 5002): " service_port
    read -p "Enter the SNI domain to route to the new service (e.g., service.example.com): " service_sni

    # Add new service configuration to HAProxy
    echo "Adding new service to HAProxy..."
    echo "
backend new_service_backend
    mode tcp
    server new_service 127.0.0.1:$service_port check" | tee -a /etc/haproxy/haproxy.cfg

    # Modify the frontend to add a rule for the new service
    sed -i "/frontend https_in/a \    use_backend new_service_backend if { req_ssl_sni -i $service_sni }" /etc/haproxy/haproxy.cfg

    # Restart HAProxy to apply changes
    systemctl restart haproxy

    echo "New service added to HAProxy."
}

# Main script starts here
echo "1. Install and configure Caddy and HAProxy from scratch."
echo "2. Add a new service to an existing HAProxy setup."
read -p "Choose an option (1 or 2): " choice

if [ "$choice" == "1" ]; then
    read -p "Enter the domain to be served by Caddy: " domain
    if ! command -v caddy &> /dev/null || ! command -v haproxy &> /dev/null; then
        install_caddy
        install_haproxy
    fi
    configure_caddy_haproxy
elif [ "$choice" == "2" ]; then
    if ! command -v haproxy &> /dev/null; then
        echo "HAProxy is not installed. Installing now."
        install_haproxy
    fi
    add_service_to_haproxy
else
    echo "Invalid choice. Exiting."
    exit 1
fi
