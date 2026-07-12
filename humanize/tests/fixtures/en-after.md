I rewrote the auth handler last night. It works now, but I'm not thrilled with it.

The retry logic is fine. The error messages still lump three failure modes into one
500, so on-call has to guess. I'll split those next.
