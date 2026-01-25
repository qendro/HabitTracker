# Resend Email Setup - Critical Issue Found

## Problem
The UserNotifier was using a hardcoded email `contact@example.com` which will FAIL with Resend.

## What I Fixed
1. Updated `lib/habit_tracker/accounts/user_notifier.ex` to use the configured `SENDER_EMAIL` environment variable
2. Added comprehensive logging to track email delivery
3. Added error handling to catch and log failures

## Required: Verify Your Domain in Resend

**CRITICAL**: Resend requires domain verification before sending emails.

### Steps to Verify Domain:

1. Go to https://resend.com/domains
2. Add domain: `habbits.xyz`
3. Add the DNS records Resend provides to your domain registrar
4. Wait for verification (usually 5-10 minutes)

### DNS Records You'll Need to Add:
Resend will give you specific records like:
- TXT record for domain verification
- DKIM records for email authentication
- SPF records

### Alternative: Use Resend's Test Domain
For immediate testing, you can use Resend's onboarding domain:
- Set `SENDER_EMAIL=onboarding@resend.dev` in Gigalixir config
- This works immediately but shows "via resend.dev" in emails

## Test After Deployment

1. Try creating a new account on https://habbits.xyz
2. Check Gigalixir logs: `make gigalixir-logs`
3. Look for log messages:
   - "Sending email" - email attempt
   - "Email sent successfully" - success
   - "Failed to send email" - failure with error details

## Current Configuration
- RESEND_API_KEY: ✅ Set
- SENDER_EMAIL: ✅ Set to noreply@habbits.xyz
- APP_URL: ✅ Set to https://habbits.xyz

## If Still Not Working
Check Resend dashboard at https://resend.com/emails for delivery status and errors.
