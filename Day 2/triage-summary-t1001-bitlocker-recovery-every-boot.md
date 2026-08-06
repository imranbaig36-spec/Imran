# Triage Summary: T-1001 BitLocker Recovery Prompt on Every Boot

## Summary (one line)
New Windows 11 laptop is reported to prompt for BitLocker recovery key at every boot.

## Impact (who/how many/business urgency)
- Who is affected: user on ticket T-1001 (to-verify)
- How many affected: one device reported so far (to-verify broader scope)
- Business urgency: to-verify

## Known Facts
- Ticket reference: T-1001
- Device context: new Windows 11 laptop
- Reported behavior: BitLocker recovery key prompt appears every boot

## Missing Information to Gather
- Whether the device reaches Windows normally after entering the recovery key (to-verify)
- Start point of issue (first boot only, post-update, post-BIOS/firmware change) (to-verify)
- Whether this affects only this laptop or multiple newly issued laptops (to-verify)
- User/business impact details (blocked from work, delay only, critical deadlines) (to-verify)
- Current boot setup (docking, external USB devices, boot order changes) (to-verify)
- TPM and Secure Boot current status from approved support checks (to-verify)
- Recovery key escrow availability in approved enterprise system (to-verify)

## Likely Category
- Security/Encryption incident: BitLocker recovery loop on endpoint (to-verify service taxonomy mapping)

## First Diagnostic Step
- Confirm recovery key escrow and then perform a controlled reboot validation while capturing whether recovery is requested again, to establish if the behavior is consistent on every startup.
