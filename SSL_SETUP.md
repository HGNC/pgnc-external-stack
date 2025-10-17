# SSL Certificate Setup and Auto-Renewal

This document provides comprehensive instructions for setting up SSL certificates and automatic renewal for the PGNC External Stack using the modern Docker Compose workflow.

## Overview

Let's Encrypt SSL certificates expire every 90 days. The PGNC External Stack provides complete certificate management including:

- **Initial certificate provisioning**: Step-by-step setup for first-time SSL certificate creation
- **Google Cloud DNS integration**: Automated DNS-01 challenge handling
- **Modern cert-renewal.sh v2.0**: Replaces deprecated `total-refresh.sh` with Docker Compose profiles
- **Container tool auto-detection**: Supports both Docker and Podman with automatic detection
- **Intelligent nginx management**: Automatically restarts nginx only when needed
- **Comprehensive error handling**: Detailed logging and troubleshooting information

## Prerequisites

- PGNC External Stack repository cloned
- Docker or Podman with Compose plugin installed
- Google Cloud account with billing enabled
- Domain name with DNS managed by Google Cloud DNS
- Basic familiarity with command line operations

## Initial Certificate Setup

### 1. Google Cloud Service Account Setup

Before requesting certificates, you need a Google Cloud service account with DNS administration permissions:

```bash
# Login to Google Cloud Console or use gcloud CLI
gcloud auth login

# Set your project
gcloud config set project YOUR_PROJECT_ID

# Create a service account for Certbot DNS management
gcloud iam service-accounts create certbot-dns-admin \
    --description="Service account for Let's Encrypt DNS challenges" \
    --display-name="Certbot DNS Admin"

# Grant DNS Admin role to the service account
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:certbot-dns-admin@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/dns.admin"

# Create and download the service account key
gcloud iam service-accounts keys create ./gcp-key.json \
    --iam-account=certbot-dns-admin@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Secure the key file
chmod 600 ./gcp-key.json
```

### 2. Environment Configuration

Configure your environment variables for SSL certificate management:

```bash
# Copy the sample environment file
cp sample.env .env

# Add or update these SSL-specific variables in .env
cat >> .env << EOF

# SSL Certificate Configuration
GCP_KEY_FILE=./gcp-key.json
GCP_PROJECT=your-gcp-project-name
GCP_DNS_ZONE=your-dns-zone-name
CERTBOT_EMAIL=your-email@domain.com
DOMAIN_NAME=yourdomain.com

# Optional: DNS Challenge Configuration
GCP_DNS_TTL=300             # DNS TTL in seconds
GCP_DNS_PROPAGATION_WAIT=60 # DNS propagation wait time in seconds
EOF
```

**Important**: Replace the placeholder values with your actual:
- `your-gcp-project-name`: Your Google Cloud project ID
- `your-dns-zone-name`: Your managed DNS zone name in Google Cloud DNS
- `your-email@domain.com`: Email address for Let's Encrypt account registration
- `yourdomain.com`: Your primary domain name

### 3. Build the Certbot Container

Build the Certbot service container with Google Cloud DNS plugin:

```bash
# Build the Certbot container
docker compose build certbot

# Verify the build was successful
docker compose --profile ssl run --rm certbot --version
```

### 4. Request Your First Certificate

**Always test with dry-run first** to avoid Let's Encrypt rate limiting:

```bash
# Test certificate request with dry-run (no actual certificate issued)
docker compose --profile ssl run --rm certbot certonly --dry-run \
    --dns-google \
    --dns-google-credentials /app/gcp-key.json \
    -d yourdomain.com
```

If the dry-run succeeds, request the actual certificate:

```bash
# Request the real certificate
docker compose --profile ssl run --rm certbot certonly \
    --dns-google \
    --dns-google-credentials /app/gcp-key.json \
    -d yourdomain.com
```

#### Multiple Domains and Wildcards

For multiple domains or wildcard certificates, add multiple `-d` flags:

```bash
# Multiple specific domains
docker compose --profile ssl run --rm certbot certonly \
    --dns-google \
    --dns-google-credentials /app/gcp-key.json \
    -d yourdomain.com \
    -d www.yourdomain.com \
    -d api.yourdomain.com

# Wildcard certificate (covers all subdomains)
docker compose --profile ssl run --rm certbot certonly \
    --dns-google \
    --dns-google-credentials /app/gcp-key.json \
    -d yourdomain.com \
    -d "*.yourdomain.com"
```

### 5. Verify Certificate Installation

```bash
# List all certificates and their expiration dates
docker compose --profile ssl run --rm certbot certificates

# Start your full stack including nginx with SSL
docker compose up -d

# Verify nginx is running and configured correctly
docker compose ps nginx

# Test SSL endpoint
curl -vI https://yourdomain.com

# Check certificate expiration dates
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com </dev/null 2>/dev/null | openssl x509 -noout -dates
```

### 6. Google Cloud DNS Integration Details

The certificate issuance and renewal process uses Google Cloud DNS for DNS-01 challenges:

#### How DNS-01 Challenges Work

1. **Challenge Creation**: Certbot requests a certificate from Let's Encrypt
2. **DNS Record Creation**: The Google Cloud DNS plugin automatically creates a `_acme-challenge` TXT record
3. **Domain Validation**: Let's Encrypt queries the TXT record to verify domain ownership
4. **Certificate Issuance**: Upon successful validation, the certificate is issued
5. **DNS Cleanup**: The temporary TXT record is automatically removed

#### Debugging DNS Issues

```bash
# Test Google Cloud authentication
docker compose --profile ssl run --rm certbot sh -c \
    "gcloud auth activate-service-account --key-file=/app/gcp-key.json && gcloud auth list"

# List your DNS zones
docker compose --profile ssl run --rm certbot sh -c \
    "gcloud auth activate-service-account --key-file=/app/gcp-key.json && \
     gcloud dns managed-zones list --project=\$GCP_PROJECT"

# Check DNS propagation during challenges
dig TXT _acme-challenge.yourdomain.com

# Increase propagation wait time if needed
echo "GCP_DNS_PROPAGATION_WAIT=120" >> .env
```

## Modern Renewal Script Features

### cert-renewal.sh v2.0 Capabilities

- **Container tool detection**: Automatically detects and validates Docker or Podman
- **Dry run support**: Test renewals without making actual changes
- **Nginx management**: Intelligent nginx restart after successful renewal
- **Error handling**: Comprehensive error detection and reporting
- **Flexible configuration**: Environment variables and command-line options

### Command-Line Options

```bash
# Standard renewal with auto-detection
./cert-renewal.sh

# Test renewal without making changes
./cert-renewal.sh --dry-run

# Force specific container tool
./cert-renewal.sh --container-tool docker
./cert-renewal.sh --container-tool podman

# Control nginx restart behavior
./cert-renewal.sh --no-restart        # Skip nginx restart
./cert-renewal.sh --restart-nginx     # Force nginx restart (default)

# Get help
./cert-renewal.sh --help
```

## Automated Renewal Setup

After completing the initial certificate setup above, configure automated renewal:

### 1. Verify Initial Setup

Ensure your environment is properly configured and certificates are already issued:

```bash
# Check that SSL environment variables are set
grep -E '^(GCP_PROJECT|GCP_DNS_ZONE|GCP_KEY_FILE|DOMAIN_NAME)=' .env

# Verify service account key exists
ls -la "$(grep '^GCP_KEY_FILE=' .env | cut -d'=' -f2)"

# Verify certificates are already issued
docker compose --profile ssl run --rm certbot certificates

# Test that certbot service can be built
docker compose build certbot
```

### 2. Test the Renewal Process

Before setting up automation, test the renewal process:

```bash
# Test with dry run (recommended first step)
./cert-renewal.sh --dry-run

# If dry run succeeds, test actual renewal
./cert-renewal.sh

# Test container tool detection
./cert-renewal.sh --container-tool docker
./cert-renewal.sh --container-tool podman  # if you use Podman
```

### 3. Set Up Automated Renewal

#### Option A: Standard Twice-Daily Renewal (Recommended)

```bash
# Edit your crontab
crontab -e

# Add this line (adjust the path to your actual project directory):
30 2,14 * * * cd /path/to/pgnc-external-stack && ./cert-renewal.sh >> /var/log/pgnc-cert-renewal.log 2>&1
```

#### Option B: Weekly with Dry Run Test

```bash
# Weekly dry run test (Sundays at 3:00 AM)
0 3 * * 0 cd /path/to/pgnc-external-stack && ./cert-renewal.sh --dry-run >> /var/log/pgnc-cert-renewal.log 2>&1

# Weekly actual renewal (Sundays at 3:30 AM)
30 3 * * 0 cd /path/to/pgnc-external-stack && ./cert-renewal.sh >> /var/log/pgnc-cert-renewal.log 2>&1
```

#### Option C: Custom Environment Variables

For advanced setups, use environment variables:

```bash
# Create a wrapper script with custom settings
cat > /usr/local/bin/pgnc-cert-renewal.sh << 'EOF'
#!/bin/bash
export CONTAINER_TOOL="podman"
export RESTART_NGINX="false"
cd /path/to/pgnc-external-stack && ./cert-renewal.sh >> /var/log/pgnc-cert-renewal.log 2>&1
EOF

chmod +x /usr/local/bin/pgnc-cert-renewal.sh

# Use in crontab
30 2,14 * * * /usr/local/bin/pgnc-cert-renewal.sh
```

### 4. Create Log Directory

Ensure the log directory exists and is writable:

```bash
# Create log file with proper permissions
sudo touch /var/log/pgnc-cert-renewal.log
sudo chown $(whoami):$(whoami) /var/log/pgnc-cert-renewal.log
chmod 644 /var/log/pgnc-cert-renewal.log
```

### 5. Monitor and Verify Setup

After setting up cron jobs:

```bash
# Verify crontab entries
crontab -l | grep cert-renewal

# Check cron service status
systemctl status cron  # Ubuntu/Debian
sudo launchctl list | grep cron  # macOS

# Test the cron environment (useful for debugging)
# Create a test script to verify cron can find Docker/Podman
echo "0 */6 * * * cd /path/to/pgnc-external-stack && ./cert-renewal.sh --dry-run" | crontab
```

## Manual Certificate Management

### Direct Renewal Commands

```bash
# Standard renewal (recommended)
./cert-renewal.sh

# Test renewal without changes
./cert-renewal.sh --dry-run

# Force renewal even if not due
docker compose --profile ssl run --rm certbot renew --force-renewal

# Request new certificates for additional domains
docker compose --profile ssl run --rm certbot certonly --dns-google --dns-google-credentials /app/gcp-key.json -d newdomain.com
```

### Certificate Status and Management

```bash
# List all certificates and their expiration dates
docker compose --profile ssl run --rm certbot certificates

# Check specific certificate details
openssl x509 -in /path/to/cert.pem -text -noout

# Verify nginx SSL configuration
docker compose exec nginx nginx -t

# Test SSL configuration with external tools
ssl-cert-check -c /etc/letsencrypt/live/yourdomain.com/cert.pem
curl -vI https://yourdomain.com
```

## Troubleshooting

### Modern Script Issues

1. **Container tool detection fails**:
   ```bash
   # Check if Docker/Podman is installed and running
   docker version  # or podman version
   docker info     # or podman info
   
   # Force specific tool if auto-detection fails
   ./cert-renewal.sh --container-tool docker
   ```

2. **Permission or authentication errors**:
   ```bash
   # Verify script permissions
   chmod +x cert-renewal.sh
   
   # Check service account key
   ls -la "$(grep '^GCP_KEY_FILE=' .env | cut -d'=' -f2)"
   
   # Test GCP authentication manually
   gcloud auth activate-service-account --key-file="$(grep '^GCP_KEY_FILE=' .env | cut -d'=' -f2)"
   gcloud dns managed-zones list --project="$(grep '^GCP_PROJECT=' .env | cut -d'=' -f2)"
   ```

3. **DNS challenge failures**:
   ```bash
   # Increase propagation wait time
   echo "GCP_DNS_PROPAGATION_WAIT=120" >> .env
   
   # Test DNS resolution
   dig TXT _acme-challenge.yourdomain.com
   
   # Check DNS zone configuration
   gcloud dns record-sets list --zone="$(grep '^GCP_DNS_ZONE=' .env | cut -d'=' -f2)" --project="$(grep '^GCP_PROJECT=' .env | cut -d'=' -f2)"
   ```

4. **Nginx restart issues**:
   ```bash
   # Check nginx service status
   docker compose ps nginx
   
   # Manual nginx restart
   docker compose restart nginx
   
   # Skip automatic nginx restart
   ./cert-renewal.sh --no-restart
   ```

5. **Cron job failures**:
   ```bash
   # Check cron logs
   grep CRON /var/log/syslog | tail -20  # Ubuntu/Debian
   log show --predicate 'process == "cron"' --last 1d  # macOS
   
   # Test cron environment
   # Run this to see what environment cron has:
   * * * * * env > /tmp/cron-env.txt
   
   # Compare with your shell environment
   env > /tmp/shell-env.txt
   diff /tmp/shell-env.txt /tmp/cron-env.txt
   ```

### Legacy Issues (deprecated total-refresh.sh)

**⚠️ Note**: If you see references to `total-refresh.sh`, update to the modern workflow:

```bash
# Replace old cron entries
# Old: ./total-refresh.sh --container-tool docker --renew-certs
# New: ./cert-renewal.sh

# Update any custom scripts that call total-refresh.sh
grep -r "total-refresh.sh" . --exclude-dir=.git
```

## Security Notes

- Keep `certbot/gcp-key.json` secure and not in version control
- Monitor renewal logs for failures
- Set up alerts if renewal fails consistently
- Test the renewal process after any infrastructure changes

## Frequency Recommendations

- **Production**: Run twice daily (current setup)
- **Development**: Run daily or manually
- **Testing**: Run manually as needed

The renewal process will only renew certificates that are due for renewal (within 30 days of expiration), so running it frequently is safe and recommended.
