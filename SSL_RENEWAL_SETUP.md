# SSL Certificate Auto-Renewal Setup

This document provides instructions for setting up automatic SSL certificate renewal for the PGNC External Stack.

## Overview

Let's Encrypt SSL certificates expire every 90 days. To prevent service interruption, you need to set up automatic renewal using cron jobs.

## Files Added

- `cert-renewal.sh` - Standalone script for certificate renewal (cron-friendly)

## Setup Instructions

### 1. Test the Renewal Process

First, test that the renewal process works manually:

```bash
# Test the renewal functionality using the dedicated renewal script
./cert-renewal.sh docker
```

### 2. Set Up Cron Job

Add a cron job to run certificate renewal twice daily:

```bash
# Edit your crontab
crontab -e

# Add this line (adjust the path to your actual project directory):
30 2,14 * * * cd /path/to/pgnc-external-stack && ./cert-renewal.sh docker >> /var/log/pgnc-cert-renewal.log 2>&1
```

This will:

- Run at 2:30 AM and 2:30 PM daily
- Log output to `/var/log/pgnc-cert-renewal.log`
- Use Docker as the container tool

### 3. Create Log Directory (if needed)

Ensure the log directory exists:

```bash
sudo touch /var/log/pgnc-cert-renewal.log
sudo chown $(whoami):$(whoami) /var/log/pgnc-cert-renewal.log
```

### 4. Monitor Renewal

Check the renewal logs periodically:

```bash
# View recent renewal attempts
tail -f /var/log/pgnc-cert-renewal.log

# Check cron job status
systemctl status cron  # Ubuntu/Debian
sudo launchctl list | grep cron  # macOS
```

## Manual Renewal

You can manually renew certificates at any time:

```bash
# Using the dedicated renewal script
./cert-renewal.sh docker
```

## Troubleshooting

### Common Issues

1. **Permission denied**: Ensure scripts are executable

   ```bash
   chmod +x total-refresh.sh cert-renewal.sh
   ```

2. **Container not running**: The nginx service must be running for renewal

   ```bash
   docker compose ps nginx
   # If not running, start the environment first
   ./RUN.sh
   ```

3. **Missing credentials**: Ensure `certbot/gcp-key.json` exists and is valid

4. **Cron not working**: Check cron service is running and logs

   ```bash
   # Check cron logs (Ubuntu/Debian)
   grep CRON /var/log/syslog
   
   # Check cron logs (macOS)
   log show --predicate 'process == "cron"' --last 1d
   ```

### Certificate Status

Check current certificate status:

```bash
# Check certificate expiration
docker compose --profile ssl run --rm certbot certificates

# Test nginx SSL configuration
docker compose exec nginx nginx -t
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
