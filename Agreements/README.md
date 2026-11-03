# Toti agreements

## Current content update: November 3, 2026 (stable URL path: 2026-10-30)

Both documents have been rewritten against the current Toti online implementation. Their format follows the Bibi agreement reference: title/date, operator/contact fields, numbered sections, feature-specific privacy subsections and a final email field. Bibi functionality, service settings and contact information were not copied.

- [Terms HTML source](TermsOfService.html) and [local PDF](2026-10-30/TermsOfService.pdf): 12 sections, 4 pages.
- [Privacy HTML source](PrivacyPolicy.html) and [local PDF](2026-10-30/PrivacyPolicy.pdf): 9 sections with feature subsections, 5 pages.
- [Public Terms PDF](https://gjodhvpzkdnxdjmorjfw.supabase.co/storage/v1/object/public/toti-agreements/2026-10-30/TermsOfService.pdf)
- [Public Privacy PDF](https://gjodhvpzkdnxdjmorjfw.supabase.co/storage/v1/object/public/toti-agreements/2026-10-30/PrivacyPolicy.pdf)

The user-confirmed contact email is roywood5667@icloud.com. It appears at the start and end of both documents. Email-placeholder instructions have been removed, and the document date is November 3, 2026. The user-confirmed operator legal name is Chengdu Yuehui Xingyu Technology Co., Ltd. Both documents now identify this operator and no longer contain the metadata draft-status notice or blank operator/contact fields. Unknown provider-log/backup retention periods are not invented. This operator/contact update does not re-audit later application feature changes. This revision replaces the previous device-only descriptions with actual online behavior; it is not a claim of final legal approval or production acceptance.

## Content basis

Reviewed the current guest login/session implementation, backend contract and release checklist, online media upload/read/review and cleanup code, archive consent UI, account deletion, wallet availability, room/chat flows and the app permissions. The documents distinguish cloud Notebook from the local archive, server-saved messages from recipient read receipts, pending/rejected images from approved images, actual reports from completed staff review, and disabled payments/RTC from available features. They disclose residual local retry files and the difference between logout, cloud deletion and local device removal.

Relevant external references checked on October 30:

- [Supabase data residency and transfers](https://supabase.com/legal/privacy-resources/data-residency-and-transfers-faq): selected-region hosting does not guarantee that CDN, operational logs or support remain in that region.
- [Apple account deletion guidance](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion): separate account deletion from logout and explain pending cleanup and retained copies.
- [Apple review guidelines](https://developer.apple.com/app-store/review/guidelines/): privacy disclosures and user-generated content requirements remain release obligations.

## Hosting and application references

Published through the signed-in Toti Supabase dashboard to the existing public toti-agreements bucket under 2026-10-30/. Public downloads need no key, Authorization header, login or signed token. There are no new public write permissions, and private user-media settings were not changed. Google Docs is not a source-editing or delivery dependency.

The user explicitly requested keeping both exact 2026-10-30 URLs on November 3, so those two objects were replaced in place. TotiIdentity retains these URLs and pins the updated SHA-256 values; Login and Settings continue to use the shared PDF reader. Online acceptance derives its version from those hashes. Earlier app builds pinning the previous bytes will reject the replaced PDFs and need a rebuild/update with the new hashes. No hash validation was removed. The previous root-level PDFs remain intact for existing versions that pin their old bytes; they are historical documents, not the current source configuration.

## Verification

- Rendered all nine PDF pages. Visually inspected the four pages containing the changed email; the other five pages are pixel-identical to the previously inspected operator revision.
- Extracted PDF text contains every HTML content block; Toti name, November 3 date and roywood5667@icloud.com are present. The email occurs twice in each PDF. Both identify Chengdu Yuehui Xingyu Technology Co., Ltd. and contain no metadata draft-status notice. No Bibi/Tito name or obsolete email-placeholder text is present.
- Independent anonymous downloads returned HTTP 200/application/pdf. Their byte contents matched the generated files exactly.
- The dashboard confirms replacement of the existing objects; public-read bucket behavior is unchanged.
- Static verification confirmed both app URLs and hash values match the downloaded PDFs. git diff --check passed.
- No iOS build, type check, app launch, simulator test, live guest creation or business-data mutation was performed for this document update.

See [publication manifest](publication.json) for exact public URLs, hashes and sizes. Local verification renderings, extracted text and the dashboard screenshot are under /tmp/toti-agreement-icloud-20261103/. PDFs are intentionally ignored by Git under the existing binary-artifact policy; the HTML sources, renderer and manifest support regeneration.

## Updating the documents

Edit the HTML sources in this directory. Generate PDFs with the bundled Python environment and reportlab:

    python3 TotiMusic/scripts/prepare_agreement_pdfs.py --version YYYY-MM-DD

Review every rendered page, verify anonymous public bytes, and update TotiIdentity hashes and publication.json together. Keep the exact user-specified public URLs unless the user requests a URL change. Replacing bytes at these fixed URLs requires an app update for builds pinning older hashes; preserve this compatibility limitation in delivery notes.
