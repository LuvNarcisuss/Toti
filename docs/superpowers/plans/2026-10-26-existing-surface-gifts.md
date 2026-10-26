# Existing-surface diamond gifts implementation plan

Goal: Extend the existing gift picker to Lounge post details, and preserve selected Voice recipients.

Scope: Existing nine gifts, prices, wallet, effects and five tabs only. User explicitly excluded profiles and chats from gifting. Ordinary messages, replies, posts and private notes remain free. No remote delivery or recipient earnings are claimed. Confirmation explicitly describes a local effect and record.

Architecture: Codable gift context is optional on existing wallet activities. Debit and purchase credit share one serialized queue. AppStore validates eligible destinations before spending; WalletStore locks overlapping UI actions. Existing gift picker shows recipient, total, balance and local-service boundary before confirmation.

- [x] Reproduce overlapping gift debits with the local StoreKit service test.
- [x] Add backward-compatible destination/recipient metadata and serialize wallet mutations.
- [x] Reuse the picker from existing post details; fix Voice recipient selection.
- [x] Cover persistence, insufficient funds, failed writes, ineligible targets and local UI confirmation/cancellation.
- [x] Build, install and run current sources on Toti UI Acceptance; run relevant tests and leave the latest app running.

Validation: Local StoreKit only; no Apple sandbox or production charge. Keep com.toti.music, StoreKit 1, seven IAP IDs and iPhone-only destinations. Preserve old ledger entries. Verify pending purchase credits cannot overwrite gift debits, and logout cannot clear an in-flight spend.

Result: 16 service tests, 3 gift UI tests and 23 core tests passed. See `../../gift-verification/README.md`. Independent review findings about long confirmation text and saving-time dismissal were addressed.
