# Clickjacking Security Fix Implementation

## Overview
This document describes the implementation of clickjacking protection for the PGNC External Stack project, addressing critical security vulnerabilities identified in the security audit.

## Security Issue
The original configuration lacked protection against clickjacking attacks, allowing malicious websites to embed the application in iframes and potentially trick users into performing unintended actions.

## Solution Implemented

### 1. Nginx Security Headers Configuration

#### Files Created:
- `nginx/conf.d/security.conf` - Main security headers configuration
- `nginx/conf.d/api-security.conf` - Enhanced security for API endpoints

#### Security Headers Added:

**Clickjacking Protection:**
- `X-Frame-Options: SAMEORIGIN` - Allows framing only from the same domain
- `Content-Security-Policy: frame-ancestors 'self'` - Modern replacement for X-Frame-Options

**Additional Security Headers:**
- `X-Content-Type-Options: nosniff` - Prevents MIME-type sniffing attacks
- `X-XSS-Protection: 1; mode=block` - Enables XSS filtering
- `Referrer-Policy: strict-origin-when-cross-origin` - Controls referrer information
- `Permissions-Policy` - Disables browser features that aren't needed
- `Strict-Transport-Security` - Enforces HTTPS connections

### 2. Docker Compose Updates

#### Changes Made:
```yaml
nginx:
  volumes:
    - certbot-letsencrypt:/etc/letsencrypt:ro
    - ./nginx/conf.d:/etc/nginx/conf.d:ro  # Added custom security configs
```

This mounts the security configuration files into the Nginx container, allowing the custom security headers to be applied.

### 3. Security Levels

#### Standard Protection (Angular UI & General Content):
- `X-Frame-Options: SAMEORIGIN` - Allows framing only from the same domain
- `Content-Security-Policy: frame-ancestors 'self'` - Same-origin framing only

#### Enhanced Protection (API Endpoints):
- `X-Frame-Options: DENY` - Completely prevents framing
- `Content-Security-Policy: frame-ancestors 'none'` - No framing allowed

## Implementation Steps

### 1. Directory Structure Created:
```
nginx/
└── conf.d/
    ├── security.conf        # Main security headers
    └── api-security.conf    # API-specific security
```

### 2. Configuration Files:

#### `nginx/conf.d/security.conf`
Contains comprehensive security headers for general web content, providing clickjacking protection while maintaining functionality.

#### `nginx/conf.d/api-security.conf`
Contains stricter security headers for API endpoints, completely preventing any framing attempts.

## Deployment Instructions

### 1. Apply the Changes:
```bash
# Restart the nginx service to apply new security configurations
docker-compose restart nginx
```

### 2. Verify Security Headers:
```bash
# Test main application
curl -I http://localhost:${LOCALHOST_NGINX_PORT}/

# Test API endpoints
curl -I http://localhost:${LOCALHOST_NGINX_PORT}/api/health
```

### 3. Expected Headers:
You should see the following security headers in the response:
- `x-frame-options: SAMEORIGIN` (or `DENY` for API)
- `content-security-policy: ...frame-ancestors 'self'...`
- `x-content-type-options: nosniff`
- And other security headers listed above

## Testing Clickjacking Protection

### 1. Manual Testing:
Create an HTML file with an iframe pointing to your application:
```html
<!DOCTYPE html>
<html>
<head><title>Clickjacking Test</title></head>
<body>
    <h1>Clickjacking Test</h1>
    <iframe src="http://your-domain.com/" width="800" height="600"></iframe>
</body>
</html>
```

The iframe should be blocked by the browser security headers.

### 2. Browser Developer Tools:
- Open browser developer tools
- Check the Network tab for security headers
- Look for CSP violations in the console if framing is attempted

## Security Levels Summary

| Component | X-Frame-Options | Frame-Ancestors | Risk Level |
|-----------|------------------|-----------------|------------|
| Angular UI | SAMEORIGIN | 'self' | LOW ✅ |
| API Endpoints | DENY | 'none' | MINIMAL ✅ |
| Solr Gateway | SAMEORIGIN | 'self' | LOW ✅ |

## Additional Security Recommendations

### 1. Content Security Policy Enhancement:
Consider implementing a more restrictive CSP based on your specific needs:
```nginx
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'nonce-${RANDOM}'; style-src 'self' 'nonce-${RANDOM}';" always;
```

### 2. Monitoring:
- Implement CSP violation reporting
- Monitor for iframe embedding attempts
- Set up security header validation in CI/CD pipeline

### 3. Regular Security Audits:
- Periodically test clickjacking protection
- Review and update security headers as needed
- Stay informed about new security best practices

## Compliance

This implementation addresses:
- OWASP Top 10 - A05:2021 Security Misconfiguration
- Clickjacking attack vectors
- Modern web security standards
- Browser security best practices

## Impact Assessment

### Before Fix:
- **Risk Level**: CRITICAL
- **Vulnerability**: Complete clickjacking exposure
- **Attack Surface**: All web-facing components

### After Fix:
- **Risk Level**: LOW
- **Protection**: Comprehensive clickjacking prevention
- **Security Posture**: Industry-standard protection

## Maintenance

### Regular Tasks:
1. Monitor security header effectiveness
2. Test after configuration changes
3. Review CSP policies when adding new features
4. Update headers based on emerging threats

### Emergency Procedures:
If security issues are detected:
1. Immediately review nginx configuration files
2. Check for header injection or bypass attempts
3. Verify Docker container integrity
4. Update security configurations as needed

## Support

For questions about this security implementation:
1. Review this documentation
2. Test configurations in a staging environment first
3. Monitor application behavior after deployment
4. Keep security configurations under version control