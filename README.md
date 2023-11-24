

# Reverse Proxy Setup with HAProxy and Caddy

This repository contains a shell script that automates the setup of HAProxy and Caddy to create a reverse proxy configuration. The script configures HAProxy to route traffic based on Server Name Indication (SNI) and sets up Caddy to handle HTTPS traffic on a specified domain. It also includes configuration for routing to a 'sing-box' backend.

## Getting Started

These instructions will guide you through the process of using the script to set up your reverse proxy configuration.

### Prerequisites

- A Debian or Ubuntu-based system.
- Root privileges on the server.
- Basic understanding of HAProxy and Caddy configurations.

### Installation

To install and run the script, use the following commands:

```bash
wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/devAlikhani/reverse_haproxy_sing-box/main/install.sh"
chmod 700 /root/install.sh
/root/install.sh
```

### Usage

1. **Run the Script**: The script will prompt you to enter the domain name to be served by Caddy.

2. **Automatic Configuration**: The script checks if Caddy and HAProxy are installed. If not, it will install them. Then, it configures Caddy to listen for HTTPS traffic and HAProxy to route traffic based on SNI.

3. **Restart Services**: The script will automatically restart Caddy and HAProxy to apply the new configurations.

### Customization

- You can modify the script to include additional configurations or adjust existing settings.
- The script sets up basic configurations, so you may need to fine-tune them based on your specific requirements.

## Notes

- Ensure that no other service is using the ports designated in the script.
- Always test the setup in a controlled environment before deploying it in production.
- Make sure to update firewall rules to allow traffic on the configured ports.

## Contributing

Contributions to improve the script or documentation are welcome. Please feel free to fork the repository and submit pull requests.

## License

This project is licensed under the [MIT License](LICENSE) - see the LICENSE file for details.

---

You can save this as `README.md` in your GitHub repository. It provides a clear overview of the project, instructions for installation and usage, and additional guidance for users.