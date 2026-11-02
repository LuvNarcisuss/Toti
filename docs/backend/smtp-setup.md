# Configure Toti email OTP

Current authentication update (2026-10-28): guest-sign-in.md supersedes the email OTP entry and SMTP prerequisites described in this earlier record.
This procedure is not yet applied or verified. Fill secret credentials directly into Supabase; do not put them in source, chat or this file.

1. Use an email delivery provider you control. Verify the sender domain and its required DNS records (usually SPF and DKIM); obtain that provider's SMTP host, port, username and password. Use its documented encryption/port settings, not a guessed port. If the provider has a sandbox mode, authorize production delivery before expecting arbitrary addresses to receive codes.
2. Open [Toti SMTP settings](https://supabase.com/dashboard/project/gjodhvpzkdnxdjmorjfw/auth/smtp), under Authentication → Emails → SMTP Settings. Enable custom SMTP, set the sender email and sender name `Toti`, and enter the provider's SMTP host/port/username/password directly there. Save.
3. Open [Toti email templates](https://supabase.com/dashboard/project/gjodhvpzkdnxdjmorjfw/auth/templates). Use subject `Your Toti sign-in code`. Set the Magic Link body to `TotiMusic/Backend/email/otp.html`, which includes `{{ .Token }}`. If the dashboard exposes a separate Confirm signup template for first-time accounts, give it the same code-bearing body. Do not publish passwords or API keys in email templates.
4. In [Email provider settings](https://supabase.com/dashboard/project/gjodhvpzkdnxdjmorjfw/auth/providers), keep Email enabled and confirmation required. Keep OTP expiry at a deliberate short interval and review [rate limits](https://supabase.com/dashboard/project/gjodhvpzkdnxdjmorjfw/auth/rate-limits). Do not turn email confirmation off to bypass delivery setup.
5. Tell the implementation owner that configuration is saved. No credential is needed in that message. Authorized acceptance must then check first-time registration, later login, expiry/reuse/resend and delivery outside the organization. Keep the app rollout closed until that and the other release checks pass.

The current app accepts numeric email codes directly and does not depend on a magic-link callback. Deployment of tables/functions does not configure SMTP or prove delivery. No email has been sent by this setup document.

Official references: [Custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp), [Email OTP](https://supabase.com/docs/guides/auth/auth-email-passwordless), [new free-project template restriction](https://supabase.com/changelog/46599-changes-to-email-template-customisation-on-free-tier).

## Dashboard inspection on 2026-10-28

The signed-in Chrome session opened the dedicated Toti project's Emails settings. Custom SMTP was disabled. Expanding the form showed empty sender email, host, username and password fields; the default port displayed 465. The Templates page explicitly required custom SMTP before subject/body editing. No SMTP configuration or template was saved and no email was sent. The form was left open with the unsaved sender name Toti, awaiting the user's selected provider and verified sender. Browser evidence is retained locally at Assets/Verification/Backend/smtp-setup-pending.png (ignored). Do not infer an email provider or reuse another application's credentials.
