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

# Function to configure Caddy
configure_caddy() {
    echo "Configuring Caddy for $caddy_domain..."
    cat <<EOF | tee /etc/caddy/Caddyfile
{
    http_port 8083
    https_port $caddy_port
}

:8083 {
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

$caddy_domain {
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
    systemctl restart caddy
}

# Function to configure HAProxy
configure_haproxy() {
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
    use_backend caddy_backend if { req_ssl_sni -i $caddy_domain }

backend caddy_backend
    mode tcp
    server caddy_server 127.0.0.1:$caddy_port check
EOF
    systemctl restart haproxy
}

# Function to add a new service to HAProxy
add_service_to_haproxy() {
    read -p "Enter the port for the new service (e.g., 5002): " service_port
    read -p "Enter the SNI domain to route to the new service (e.g., service.example.com): " service_sni
    backend_name=$(echo "$service_sni" | tr '.' '_' | tr '-' '_')
    echo "Adding new service ($backend_name) to HAProxy..."
    echo "
backend $backend_name
    mode tcp
    server ${backend_name}_server 127.0.0.1:$service_port check" | sudo tee -a /etc/haproxy/haproxy.cfg
    sudo sed -i "/frontend https_in/a \    use_backend $backend_name if { req_ssl_sni -i $service_sni }" /etc/haproxy/haproxy.cfg
    sudo systemctl restart haproxy
}

# Main script logic
echo "1. Install and configure Caddy and HAProxy from scratch."
echo "2. Add a new service to an existing HAProxy setup."
read -p "Choose an option (1 or 2): " choice

case $choice in
    1)
        read -p "Enter the domain to be served by Caddy: " caddy_domain
        read -p "Enter the port for Caddy to listen on (e.g., 5003): " caddy_port
        if ! command -v caddy &> /dev/null || ! command -v haproxy &> /dev/null; then
            install_caddy
            install_haproxy
        fi
        configure_caddy
        configure_haproxy
        ;;
    2)
        if ! command -v haproxy &> /dev/null; then
            echo "HAProxy is not installed. Installing now."
            install_haproxy
        fi
        add_service_to_haproxy
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac
