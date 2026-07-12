# Safety rails (read before every rewrite or distill)

Apply these in order. A higher rule always wins a conflict with a lower one.

1. **Never invent facts.** Every number, name, quote, and claim in the output
   must trace to the source or the user. If a fact is missing, leave a
   `[needs author input: …]` marker — do not fabricate.
2. **Human-detection gate.** If the input already reads as genuinely
   human-written — self-corrections mid-sentence, dated slang / in-jokes,
   dialect markers, a specific personal anecdote, a recognizable individual
   voice — STOP. Only fix mechanical formatting (typos, punctuation). Do not
   rewrite the voice. Say why you stopped.
3. **Density, not presence.** One em-dash, one "however", one 排比 / rule-of-three
   is never a tell. Flag only clustered, context-free repetition (roughly 3+ of
   the same device in a short span with no logical need).
4. **Keep one rough edge.** The output must retain at least one subjective
   judgment or concrete specific — never sand text into something sterile and
   generic.
5. **Preserve meaning.** Tone, rhythm, and word choice may change; the meaning
   must not. If a proposed change alters meaning, drop it.

## Protected — never alter
Prices, numbers, dates, proper nouns, real names, quoted speech, URLs (but strip
`utm_source=chatgpt.com`-style tracking), and legal / refund clauses.
