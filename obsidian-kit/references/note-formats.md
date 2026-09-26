# Note formats by note-type

Every in-scope note has `note-type:` in frontmatter and inline tags from the taxonomy
on line 1 of the body. Tags come only from the `## Allowed` table of the taxonomy file
(`taxonomyPath` in `.obsidian-kit.json`). If no tag fits, propose one and ask the user.

## map

Name: `00__map__<series-folder-name>.md`, inside the series folder.

```
#tag/a #tag/b

## <Topic>: learning path
**One sentence: what the series explains and why.**

<fenced ASCII overview of the sections>

**0: <section name>**
- [[01__first__note]]: one-line gloss.
- [[02__second__note]]: one-line gloss.
```

## concept

Any name. One screen: 45 body lines at most.

```
#tag/a

## <Title>
**One-sentence claim.**

<fenced ASCII diagram, only if the idea has shape>

- bullet
- bullet

Related: [[Other Note]]
Sources: [name](url)
```

## takeaway

Name: `NN__<slug>.md`. Tens are the section and units are the step. Same body and
budget as concept, plus:

```
> [!example] From this session
> What happened in the session that taught this.
```

`Related:` links back to the series map `[[00__map__<series>]]`.

## literature

Any name. No line budget.

```
#tag/a

> Link: https://source

# <Title>
**One-sentence claim.**

free notes
```

For a web page source, get the body with `defuddle parse <url> --md`, then trim it.

## fleeting

Tags on line 1 and a title. Anything goes below.
