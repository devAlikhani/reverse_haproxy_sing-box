#!/bin/bash

# Function to install Caddy

SERVER_IP=$(curl -s ip.sb)


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
    http_port 8080
    https_port $caddy_port
}

$caddy_domain {
    handle /sub/* {
        root * /var/www/textfiles/
        file_serverx
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
    use_backend default_service_backend if { req_ssl_sni -i $default_sni_domain }

backend caddy_backend
    mode tcp
    server caddy_server 127.0.0.1:$caddy_port check

backend default_service_backend
    mode tcp
    server default_service 127.0.0.1:$default_service_port check
EOF

    # Restart HAProxy to apply changes
    systemctl restart haproxy
}

# Function to add a new service to HAProxy
add_service_to_haproxy() {
    read -p "Enter the port for the new service (e.g., 5002): " service_port
    read -p "Enter the SNI domain to route to the new service (e.g., service.example.com): " service_sni

    # Create a unique backend name using the SNI domain
    backend_name=$(echo "$service_sni" | tr '.' '_' | tr '-' '_')

    # Add new service configuration to HAProxy
    echo "Adding new service ($backend_name) to HAProxy..."
    echo "
backend $backend_name
    mode tcp
    server ${backend_name}_server 127.0.0.1:$service_port check" | sudo tee -a /etc/haproxy/haproxy.cfg

    # Modify the frontend to add a rule for the new service
    sudo sed -i "/frontend https_in/a \    use_backend $backend_name if { req_ssl_sni -i $service_sni }" /etc/haproxy/haproxy.cfg

    # Restart HAProxy to apply changes
    sudo systemctl restart haproxy

    echo "New service added to HAProxy."
}

configure_haproxy_ip_access() {
    read -p "Enter the port for direct IP access (e.g., 8081): " ip_access_port

    # Add new frontend/backend configuration to HAProxy
    echo "Adding direct IP access to HAProxy..."
    echo "
frontend ip_based_frontend
    bind $SERVER_IP:$ip_access_port
    mode http
    default_backend ssh_backend

backend ssh_backend
    mode http
    server caddy 127.0.0.1:5003" | sudo tee -a /etc/haproxy/haproxy.cfg

    # Restart HAProxy to apply changes
    sudo systemctl restart haproxy

    echo "Direct IP access configured in HAProxy."
}

# Main script starts here
echo "1. Install and configure Caddy and HAProxy from scratch."
echo "2. Add a new service to an existing HAProxy setup."
echo "3. Configure HAProxy for direct IP access."
read -p "Choose an option (1, 2, or 3): " choice

if [ "$choice" == "1" ]; then
    read -p "Enter the domain to be served by Caddy: " caddy_domain
    read -p "Enter the port for Caddy to listen on (e.g., 5003): " caddy_port
    read -p "Enter the SNI domain for the default service (e.g., default.example.com): " default_sni_domain
    read -p "Enter the port for the default service (e.g., 5004): " default_service_port

    if ! command -v caddy &> /dev/null || ! command -v haproxy &> /dev/null; then
        install_caddy
        install_haproxy
    fi
    configure_caddy
    configure_haproxy
elif [ "$choice" == "2" ]; then
    if ! command -v haproxy &> /dev/null; then
        echo "HAProxy is not installed. Installing now."
        install_haproxy
    fi
    elif [ "$choice" == "3" ]; then
    if ! command -v haproxy &> /dev/null; then
        echo "HAProxy is not installed. Installing now."
        install_haproxy
    fi
    configure_haproxy_ip_access
else
    echo "Invalid choice. Exiting."
    exit 1
fi
