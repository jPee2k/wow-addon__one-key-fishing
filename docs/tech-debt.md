# Technical debt

Known issues that are not fixed yet, with the reason they matter and a suggested direction. Each item says where
it was found and how serious it is. Remove an item when it is fixed (with a test), or move it to the spec of the
part that takes it on.

Severity: **high** loses data or cuts off honest players; **medium** wrong state or wasted traffic; **low**
cleanup, no wrong behaviour.

No open items. The thirteen items of the code review of 2026-10-29 on `002-shared-db` are fixed, each with a test;
the part of item 11 (a forged record) that a client cannot check on its own moved to `docs/shared-db-plan.md`
("Protection against spam and fakes"), which part 3 takes on.
