# PopHealth Map, mirror

A copy of **[pophealth.uk](https://pophealth.uk)**, served from GitHub Pages at
its default address so that networks which block the custom domain can still
reach the map.

**Live here:** https://harv334.github.io/pophealthmap-mirror/

## Why this exists

`pophealth.uk` was registered in August 2026. Web filters, including the ones
NHS trusts use, block domains they have not categorised, and a newly registered
domain is uncategorised by definition. The block is applied at the TLS
handshake, so it surfaces as a certificate warning rather than a tidy "blocked"
page, which makes it look as though something is wrong with the site. Nothing
is: the certificate is a valid Let's Encrypt one covering `pophealth.uk` and
`www.pophealth.uk`.

`github.io` has been categorised by every filtering vendor for years, so this
copy gets through.

This is a stopgap. The real fix is getting `pophealth.uk` categorised, via the
vendor submission forms and a request to the trust's IT team. Once that lands,
this mirror is still worth keeping for anyone on a network that has not caught
up.

## What is here

Only the files the site serves: `index.html`, `methodology.html`, the JSON and
GeoJSON layers, `data/map/`, and `data/meta/manifest.json`. The pipeline, the
parquet intermediates, the Worker and the repo history all stay in the
[main repo](https://github.com/Harv334/pophealthmap).

Two files differ from the originals, both on purpose:

| File | Difference | Why |
|---|---|---|
| `index.html` | `robots` meta is `noindex` | Two identical copies competing in search would cost both. The canonical tag still points at pophealth.uk, so any signal this copy earns is credited there. |
| `data/map/assistant.js` | `ASSISTANT_ENDPOINT` is empty | The Worker only allows the pophealth.uk origins, so a question asked from here returns 403. An empty endpoint hides the panel rather than shipping one that always fails. |

There is deliberately **no `CNAME` file**. Adding one would make this copy
redirect to pophealth.uk, which is the one thing it must not do.

`robots.txt` and `sitemap.xml` are also absent: on a project page they would sit
at `/pophealthmap-mirror/robots.txt`, which no crawler reads. The `noindex` meta
tag is what does the work here.

## Refreshing it

From this folder, with the main repo cloned alongside it:

```powershell
.\sync-mirror.ps1
git add -A
git commit -m "Refresh mirror"
git push
```

`sync-mirror.ps1` copies the served files across and reapplies both differences
above. It fails loudly if the main repo has changed either of the lines it
patches, rather than quietly publishing an indexable copy or a broken Ask
panel.

The main repo refreshes its data monthly through a scheduled workflow. This
mirror does not follow automatically, so run the sync after a data refresh if
you want the two in step. To automate it later, add a step to the main repo's
`refresh-data.yml` that pushes the served files here using a deploy key.

## Turning the Ask panel on here

1. Add `https://harv334.github.io` to `ALLOWED_ORIGINS` in
   `worker/wrangler.toml` in the main repo.
2. Redeploy the Worker.
3. Put the Worker URL back into `ASSISTANT_ENDPOINT` in
   `data/map/assistant.js`, and update `sync-mirror.ps1` to match.

## Licence

Same as the main repo: MIT for the code, and the data carries its own
attribution requirements, listed in
[DATA_LICENCES.md](https://github.com/Harv334/pophealthmap/blob/main/DATA_LICENCES.md).
