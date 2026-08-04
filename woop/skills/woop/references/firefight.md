# Mode: firefight — triage a live incident

**Fires:** mid-incident, under hard constraints. The Titanic "already hit the iceberg"
stance — no blame for the past, only damage control against the clock.

**Essence-wish reframe:** surface "make it go back to normal / hope it recovers" → essence
"maximize the outcome within the constraints that actually bind." **Name the hard constraint
explicitly** (time budget, blast radius, irreversible data loss).

**Obstacle family (tell the hunter):** rigid playbooks misread under pressure, wasted golden
time, actions that trade a small *recoverable* loss for a large *irreversible* one, and the
panic that skips the cheap high-leverage move. **What is burning time or capacity right
now?**

**Mini-example:**
- Wish: "get the service back up" → essence: "stop irreversible data corruption first,
  restore availability second."
- Obstacle: "we are tempted to restart the writer, which would replay the poisoned queue."
- Plan: "If the queue may hold poisoned messages, then freeze the consumer and snapshot
  before any restart."
