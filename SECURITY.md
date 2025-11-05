# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in JalaForm, please report it by emailing [security@yourproject.com] or creating a private security advisory on GitHub.

**Please do not report security vulnerabilities through public GitHub issues.**

## Security Measures Implemented

### Authentication & Authorization

1. **Secure Token Storage**
   - Access tokens and refresh tokens are stored using platform-specific secure storage
   - Android: Android Keystore
   - iOS: iOS Keychain
   - Web: Encrypted storage

2. **Row Level Security (RLS)**
   - All database tables have RLS policies enabled
   - Users can only access their own data
   - See `RLS_SETUP.sql` for policy details

3. **Password Security**
   - Minimum password length: 12 characters
   - Password complexity requirements enforced
   - Passwords are NEVER stored locally
   - Only email addresses are saved for "Remember Me" functionality

### Data Protection

1. **File Upload Security**
   - Magic byte validation for all image uploads
   - File size limits enforced (5MB maximum)
   - Only allowed file types: PNG, JPEG, GIF, WebP, BMP

2. **API Credentials**
   - Supabase credentials stored in environment variables
   - Never committed to version control
   - `.env` file excluded via `.gitignore`

3. **Error Messages**
   - Sanitized error messages prevent information leakage
   - Stack traces never exposed to end users
   - Detailed errors only logged server-side

### Network Security

1. **HTTPS Only**
   - All API communications use HTTPS
   - No HTTP connections allowed

2. **Rate Limiting**
   - Authentication endpoints have rate limiting
   - Protection against brute force attacks

## Security Best Practices for Developers

### Environment Variables

1. Never commit `.env` files to version control
2. Always use `.env.example` as a template
3. Rotate API keys immediately if exposed

### Database Access

1. Always use Row Level Security policies
2. Never trust client-side validation alone
3. Validate all inputs server-side

### File Uploads

1. Always validate files using magic bytes
2. Enforce file size limits
3. Scan files for malware in production

### Token Management

1. Never store tokens in SharedPreferences
2. Always use `SecureTokenStorage` for sensitive data
3. Clear all tokens on logout

## Security Checklist for Production

- [ ] Environment variables configured correctly
- [ ] `.env` file not committed to repository
- [ ] Supabase API keys rotated from defaults
- [ ] RLS policies enabled on all tables (run `RLS_SETUP.sql`)
- [ ] HTTPS enforced on all endpoints
- [ ] Error messages sanitized
- [ ] File upload validation enabled
- [ ] Secure token storage implemented
- [ ] Rate limiting configured
- [ ] Security audit completed

## Recent Security Updates

### Version 1.0.0 (2025-11-05)

**Phase 1: Critical Security Fixes**
- ✅ Moved API credentials to environment variables
- ✅ Removed plaintext password storage
- ✅ Implemented secure token storage (Android Keystore / iOS Keychain)
- ✅ Added magic byte validation for file uploads
- ✅ Increased password minimum to 12 characters
- ✅ Created RLS policies for all tables
- ✅ Sanitized error messages

**Vulnerabilities Fixed:**
- CRITICAL: Exposed Supabase API credentials
- CRITICAL: Plaintext password storage
- CRITICAL: Insecure token storage
- CRITICAL: Missing authorization checks
- HIGH: Weak file upload validation
- HIGH: Weak password requirements

## Contact

For security concerns, contact:
- Email: [security@yourproject.com]
- GitHub: [Create a private security advisory]

## Acknowledgments

We appreciate responsible disclosure of security vulnerabilities. Contributors who report valid security issues will be acknowledged in our security hall of fame (with permission).
