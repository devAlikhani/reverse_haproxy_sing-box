#!/bin/bash

# Check if running as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Prompt for the domain
read -p "Enter the domain name: " domain

# Update and install Certbot and HAProxy
echo "Updating system and installing Certbot and HAProxy..."
apt-get update
apt-get install -y certbot haproxy

# Obtain the certificate
echo "Obtaining SSL certificate for $domain..."
certbot certonly --standalone -d "$domain" --non-interactive --agree-tos -m your-email@example.com

# Combine certificates for HAProxy
echo "Combining certificates for HAProxy..."
cat /etc/letsencrypt/live/"$domain"/fullchain.pem /etc/letsencrypt/live/"$domain"/privkey.pem > /etc/haproxy/certs/"$domain".pem

# Configure HAProxy
echo "Configuring HAProxy..."
haproxy_cfg="/etc/haproxy/haproxy.cfg"

# Backup original HAProxy configuration
cp $haproxy_cfg $haproxy_cfg.bak

# Add configuration
echo "
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5000ms
    timeout client  50000ms
    timeout server  50000ms

frontend https_front
    bind *:443 ssl crt /etc/haproxy/certs/$domain.pem
    mode tcp
    tcp-request inspect-delay 5s
    tcp-request content accept if { req_ssl_hello_type 1 }

    acl is_sing_box req_ssl_sni -i $domain
    acl is_website req_ssl_sni -i $domain/sub/
    acl is_ssh req_ssl_sni -i $domain/ssh/

    use_backend sing_box_service if is_sing_box
    use_backend website_service if is_website
    use_backend ssh_service if is_ssh

backend sing_box_service
    mode tcp
    server singbox localhost:5001 check

backend website_service
    mode http
    server website localhost:<WEBSITE_PORT> check

backend ssh_service
    mode http
    server ssh localhost:<SSH_PORT> check
" > $haproxy_cfg

# Replace <WEBSITE_PORT> and <SSH_PORT> with actual port numbers
sed -i 's/<WEBSITE_PORT>/80/' $haproxy_cfg
sed -i 's/<SSH_PORT>/22/' $haproxy_cfg

# Reload HAProxy to apply the changes
echo "Reloading HAProxy..."
systemctl reload haproxy

# Set up cron job for certificate renewal
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/bin/certbot renew --quiet --post-hook 'systemctl reload haproxy'") | crontab -

echo "SSL and HAProxy setup complete."

