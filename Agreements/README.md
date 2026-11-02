# Toti agreements

## Current version: October 30, 2026

Both documents have been rewritten against the current Toti online implementation. Their format follows the Bibi agreement reference: title/date, blank operator/contact fields, numbered sections, feature-specific privacy subsections and a final email field. Bibi functionality, service settings and contact information were not copied.

- [Terms HTML source](TermsOfService.html) and [local PDF](2026-10-30/TermsOfService.pdf): 12 sections, 4 pages.
- [Privacy HTML source](PrivacyPolicy.html) and [local PDF](2026-10-30/PrivacyPolicy.pdf): 9 sections with feature subsections, 5 pages.
- [Public Terms PDF](https://gjodhvpzkdnxdjmorjfw.supabase.co/storage/v1/object/public/toti-agreements/2026-10-30/TermsOfService.pdf)
- [Public Privacy PDF](https://gjodhvpzkdnxdjmorjfw.supabase.co/storage/v1/object/public/toti-agreements/2026-10-30/PrivacyPolicy.pdf)

Contact email remains blank as requested. Operator identity is also unconfirmed; both documents retain a draft status pending that metadata. Unknown provider-log/backup retention periods and support arrangements are not invented. This revision replaces the previous device-only descriptions with actual online behavior; it is not a claim of final legal approval or production acceptance.

## Content basis

Reviewed the current guest login/session implementation, backend contract and release checklist, online media upload/read/review and cleanup code, archive consent UI, account deletion, wallet availability, room/chat flows and the app permissions. The documents distinguish cloud Notebook from the local archive, server-saved messages from recipient read receipts, pending/rejected images from approved images, actual reports from completed staff review, and disabled payments/RTC from available features. They disclose residual local retry files and the difference between logout, cloud deletion and local device removal.

Relevant external references checked on October 30:

- [Supabase data residency and transfers](https://supabase.com/legal/privacy-resources/data-residency-and-transfers-faq): selected-region hosting does not guarantee that CDN, operational logs or support remain in that region.
- [Apple account deletion guidance](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion): separate account deletion from logout and explain pending cleanup and retained copies.
- [Apple review guidelines](https://developer.apple.com/app-store/review/guidelines/): privacy disclosures and user-generated content requirements remain release obligations.

## Hosting and application references

Published through the signed-in Toti Supabase dashboard to the existing public toti-agreements bucket under 2026-10-30/. Public downloads need no key, Authorization header, login or signed token. There are no new public write permissions, and private user-media settings were not changed. Google Docs is not a source-editing or delivery dependency.

TotiIdentity now pins the new URLs and SHA-256 values; Login and Settings continue to use the shared PDF reader. Online acceptance derives its version from those hashes. An installed app needs a rebuild/update to use the new links. The previous root-level PDFs remain intact for existing versions that pin their old bytes; they are historical documents, not the current source configuration.

## Verification

- Rendered and visually inspected all nine PDF pages for text flow, clipping, headings and footers.
- Extracted PDF text contains every HTML content block; Toti name, October 30 date and blank contact fields are present. No Bibi/Tito name or email address is present in either PDF.
- Independent anonymous downloads returned HTTP 200/application/pdf. Their byte contents matched the generated files exactly.
- Storage metadata confirms both new objects and byte counts; public-read bucket behavior is unchanged.
- Static verification confirmed both app URLs and hash values match the downloaded PDFs. git diff --check passed.
- No iOS build, type check, app launch, simulator test, live guest creation or business-data mutation was performed for this document update.

See [publication manifest](publication.json) for exact public URLs, hashes and sizes. Local verification renderings, extracted text and the dashboard screenshot are under /tmp/toti-agreement-review-20261030/. PDFs are intentionally ignored by Git under the existing binary-artifact policy; the HTML sources, renderer and manifest support regeneration.

## Updating the documents

Edit the HTML sources in this directory. Generate PDFs with the bundled Python environment and reportlab:

    python3 TotiMusic/scripts/prepare_agreement_pdfs.py --version YYYY-MM-DD

Review every rendered page, publish to a new version path, verify public bytes, then update both TotiIdentity URL/hash entries together. Never replace a pinned object with different bytes without a coordinated app update. This avoids breaking older installed readers and acceptance identifiers.
