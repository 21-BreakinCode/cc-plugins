# AI-tells — English

Source lineage: blader/humanizer (33-pattern catalogue). Apply with
`safety-rails.md` — flag clusters, not isolated hits.

## Hard constraint
- **Zero em/en dashes in output.** Remove every `—`, `–`, spaced ` — `, and
  double-hyphen `--`. Replacement priority: period > comma > colon > parentheses
  > restructure. Before delivering, scan the text for `—` and `–`; any hit means
  it is not done.

## Word / phrase tells (cut or replace with the concrete thing)
- **AI vocabulary:** delve, crucial, pivotal, tapestry, testament, underscore,
  showcase, intricate/intricacies, garner, fostering, vibrant, landscape
  (abstract), interplay, align with, key (as adjective), enduring, valuable.
- **Significance inflation:** "stands/serves as a testament", "marks a pivotal
  moment", "underscores/highlights the importance of", "plays a vital role",
  "evolving landscape", "leaves an indelible mark", "deeply rooted". → replace
  with the concrete fact (a number, date, name) or delete.
- **Promotional / brochure:** nestled, in the heart of, breathtaking, must-visit,
  boasts a, renowned, rich cultural heritage, groundbreaking, stunning.
- **Copula avoidance:** "serves as / stands as / represents a" → just "is / are".
- **Signposting:** "let's dive in", "here's what you need to know", "without
  further ado", "let's break this down". → just start.
- **Fake-candor openers** used as standalone theatrical pauses: "Honestly?",
  "Look,", "Here's the thing", "Let's be honest", "Real talk".
- **Chatbot residue:** "I hope this helps", "Of course!", "Would you like me
  to…", "Let me know if…", "Here is a…".
- **Knowledge-gap filler dressed as fact:** "it is believed that", "maintains a
  low profile". → say "not documented" or cut.
- **Filler → tighter:** "in order to" → "to"; "due to the fact that" → "because";
  "at this point in time" → "now"; "it is important to note that" → (delete).

## Structure tells
- **Rule of three** forced onto every idea. Let lists be 2 or 4 when logic says so.
- **Negative parallelism** ("not only X but Y", "it's not just X, it's Y") — legit
  once; cap at one per piece.
- **Hyphenation:** hyphenate only attributively. "a high-quality report" keeps the
  hyphen; "the report is high quality" drops it. AI hyphenates uniformly everywhere.
- **Even cadence:** vary sentence length deliberately — short punchy next to long.

## False-positive guard (do NOT flag these alone)
Perfect grammar; formal vocabulary alone; one isolated "however"/"moreover"; curly
quotes (editors auto-curl); one em-dash in an otherwise human piece; one short
emphatic sentence; an unsourced claim on its own. Only a *cluster* of tells is
evidence.

## Human signals to preserve
Hard-to-fabricate specifics; mixed / unresolved feelings ("I think this is mostly
good but something bugs me"); self-corrections and mid-thought parentheticals;
uneven sentence variety.
