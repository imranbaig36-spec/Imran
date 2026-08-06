# Triage Summary: T-1005 Teams Audio Failure in Meeting Room

## Summary (one line)
Teams audio is reported as non-functional on three machines in the same meeting room.

## Impact (who/how many/business urgency)
- Who is affected: meeting room users on three machines (to-verify exact user groups)
- How many affected: three machines reported
- Business urgency: to-verify

## Known Facts
- Ticket reference: T-1005
- Reported issue: Teams audio is dead
- Scope detail: affects three machines in the same meeting room

## Missing Information to Gather
- Whether both microphone and speaker audio are affected (to-verify)
- Whether issue occurs in all meetings or one specific meeting/call (to-verify)
- Whether non-Teams audio works on affected machines (to-verify)
- Whether all three machines use the same room audio peripherals/dock path (to-verify)
- Whether issue started after any recent update or room hardware change (to-verify)

## Likely Category
- Collaboration/meeting-room endpoint audio incident (to-verify service taxonomy mapping)

## First Diagnostic Step
- On one affected machine, validate default input/output device selection in Teams and run a quick test call to confirm whether the failure is endpoint device selection versus shared room hardware path.
