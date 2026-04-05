# Privacy Commitments

This template is designed to align with strong privacy defaults inspired by the Electronic Frontier Foundation's guidance for online service providers and Do Not Track aware services.

This file is an engineering policy, not legal advice.

## Template Defaults

- Production traffic is intended to run over HTTPS with HSTS enabled.
- Session and remember-me cookies are encrypted and marked `HttpOnly`, `SameSite=Lax`, and `Secure` in production.
- The browser pipeline sends privacy-conscious security headers, including a same-origin referrer policy and a restrictive permissions policy.
- The template does not require third-party analytics, ad tech, CDNs, or remote fonts to function.
- User-uploaded profile images are intended to be served from this application, not third-party hosts.

## Operating Requirements

- Keep proxy, CDN, and infrastructure logs only as long as operationally necessary.
- Avoid storing identifiable request data longer than needed for security and debugging.
- Review any third-party script, iframe, font, analytics, or image embed before adding it.
- Make sure hosting, email, CDN, and observability providers honor the same privacy promises you make to users.
- Publish an accurate privacy notice if you deploy this template for real users.

## Review Checklist

- Verify production runs behind TLS and keeps `secure_cookies` enabled.
- Verify reverse proxy and CDN logging retention matches your privacy policy.
- Verify no new third-party browser requests were introduced.
- Verify user-visible data collection and retention are documented before release.
