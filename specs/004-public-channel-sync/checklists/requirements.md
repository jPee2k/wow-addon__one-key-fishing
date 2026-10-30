# Specification Quality Checklist: Catch Data Exchange Through a Hidden Public Channel

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-10-30
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- Three clarifications were answered by the author on 2026-10-30 (spec "Clarifications"): the protections of the
  numbers ship in 1.2.0 even if the channel does not; forged versions are closed by owner-bound versions plus
  growth limits; a channel locked by whoever took it over is answered by fallback channels every client finds the
  same way (FR-005a, SC-011; raised by a side review after the first draft). The author also noted that WoW
  Forever has items no client knows until someone finds them, which became FR-017a and replaces part 2's rule of
  dropping a contribution with an unknown item.
- A gameplay quiz with the author on 2026-10-30 (spec "Quiz on the gameplay") settled 13 questions and two follow-ups.
  It changed the spec in four places: the addon keeps two channel slots free and gives its slot up with one chat
  line when the player hits the limit (FR-005, SC-012); an item the client does not know yet shows as an "Unknown
  item" row with its ID in the tooltip, instead of not at all (FR-017a); a blocked player learns it only from
  `/okf debug` (FR-020); the member-list sentence goes on the settings page only (FR-022). The rest confirmed what
  the spec already assumed. A fact found on the way: WoW Forever allows 20 chat channels, not the 10 the plan says.
- First validation pass: three wordings were too vague to test and were made exact ("thousands of catches" became
  1,000 or more, "little data" became under 50 catches as in part 1, and FR-013 was rephrased as a cap per
  contribution). The second pass found nothing.
- `/okf share`, `/okf debug`, the setting names and "the release command" are player- and author-facing product
  surface, not implementation details, as in part 2.
- The numbers in FR-006, FR-013, FR-016 and SC-001/SC-002 (rarer announcements, one fifth from five contributions,
  1,000 and 50 catches, 60 days, 500 and 1,000 simulated clients) come from `docs/shared-db-plan.md` or are starting
  targets; `speckit-plan` should keep them as constants, and the in-game check (FR-026) may refine them.
- Technical questions for `speckit-plan` / `research.md`: how the version proof is made without a hash function in
  the game API (FR-015), how the weight cap combines with the bundled sums, how hearers pick a stranger to exchange
  with (FR-006), the channel name, how the channel is hidden from the game's channel list (FR-003, with its
  fallback), and how the fallback channels are named and found (FR-005a: names that change over time, and whether
  an addon client that becomes a channel's owner may undo a lock). Everything only the game can show gets a `VERIFY`
  marker.
- "Use the public channel" on by default was confirmed by the author in the quiz.
- Changed while planning (spec "While planning, 2026-10-30"):
  - FR-003: the client's export shows that the game's channel lists cannot be filtered, and the author chose to leave
    the channel listed there under its own name (it is in no chat window). The password prompt the game shows for a
    locked channel is now part of FR-003.
  - FR-015 and SC-007: the growth limit is measured in version steps, not in the time since a version arrived; that
    would refuse honest versions relayed slowly (research R9).
