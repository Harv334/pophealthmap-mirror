<#
  Refresh this mirror from the main repo.

  The mirror is a copy of the files pophealth.uk serves, nothing else: no
  pipeline, no parquet, no history. Two files differ from the originals on
  purpose, and this script reapplies both differences after every copy so they
  cannot be lost in a refresh:

    index.html            robots meta becomes noindex
    data/map/assistant.js ASSISTANT_ENDPOINT blanked

  Both patches fail loudly if the text they expect is missing, which is the
  point: if the main repo changes either line, this stops rather than quietly
  publishing an indexable copy or a panel that 403s.

  Usage, from this folder:
      .\sync-mirror.ps1
      .\sync-mirror.ps1 -Source D:\somewhere\else\pophealthmap
#>
[CmdletBinding()]
param(
  [string]$Source = (Join-Path (Split-Path $PSScriptRoot -Parent) "pophealthmap")
)

$ErrorActionPreference = "Stop"
$dst = $PSScriptRoot

if (-not (Test-Path (Join-Path $Source "index.html"))) {
  throw "No index.html under $Source. Point -Source at the main pophealthmap clone."
}

# Everything index.html fetches, links to, or loads as a script, plus the
# manifest it reads for the data version and the freshness label. Deliberately
# not the whole repo: the parquet intermediates and the pipeline are not served.
$rootFiles = @(
  "index.html", "methodology.html",
  "ward_data.json", "lsoa_data.json", "vcse_data.json", "cics.json",
  "pharmacies.json", "dental_practices.json", "schools.json", "libraries.json",
  "esol_providers.json", "community_centres.json",
  "greenspaces.geojson", "lsoa_boundaries.geojson",
  "ward_geometries.json", "ward_imd.csv", "og.png"
)

foreach ($d in @("data\map", "data\meta")) {
  New-Item -ItemType Directory -Force (Join-Path $dst $d) | Out-Null
}

$copied = 0
foreach ($f in $rootFiles) {
  $from = Join-Path $Source $f
  if (-not (Test-Path $from)) { Write-Warning "missing in source, skipped: $f"; continue }
  Copy-Item $from (Join-Path $dst $f) -Force
  $copied++
}
foreach ($f in (Get-ChildItem (Join-Path $Source "data\map") -File)) {
  Copy-Item $f.FullName (Join-Path $dst "data\map\$($f.Name)") -Force
  $copied++
}
Copy-Item (Join-Path $Source "data\meta\manifest.json") (Join-Path $dst "data\meta\manifest.json") -Force
$copied++

# UTF-8 without a BOM, matching how the files are written in the main repo.
function Write-Utf8NoBom([string]$path, [string]$text) {
  [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

function Patch([string]$path, [string]$find, [string]$replace, [string]$what) {
  $text = [System.IO.File]::ReadAllText($path)
  if ($text -notlike "*$find*") {
    throw "$what : could not find the expected text in $path. The main repo has changed; update sync-mirror.ps1 before publishing this mirror."
  }
  Write-Utf8NoBom $path ($text.Replace($find, $replace))
  Write-Host "  patched: $what"
}

$noindexNote = @'
<!-- MIRROR. This copy exists so the map is reachable from networks that block
     pophealth.uk, which is a domain registered in August 2026 and not yet
     categorised by the web filters NHS trusts use. github.io has been
     categorised for years and gets through.

     noindex, because two identical copies competing in search would cost both
     of them. The canonical tag below still points at pophealth.uk, so any
     signal this copy earns is credited there.

     Keep this file in step with the main repo by running sync-mirror.ps1
     rather than editing it here. -->
<meta name="robots" content="noindex, follow">
'@

Patch (Join-Path $dst "index.html") `
  '<meta name="robots" content="index, follow, max-image-preview:large">' `
  $noindexNote.TrimEnd() `
  "index.html -> noindex"

$endpointNote = @'
// MIRROR: deliberately empty, so the Ask panel does not appear here.
//
// The Worker's ALLOWED_ORIGINS only lists https://pophealth.uk and
// https://www.pophealth.uk, so a question asked from github.io comes back 403
// "Origin not allowed". A panel that is present but always fails is worse than
// no panel, and assistant.js already treats an empty endpoint as "no panel,
// map unaffected".
//
// To switch it on here: add https://harv334.github.io to ALLOWED_ORIGINS in
// worker/wrangler.toml, redeploy the Worker, then put the URL back on the line
// below. The endpoint is not a secret; the API key lives only in the Worker.
var ASSISTANT_ENDPOINT = "";
'@

Patch (Join-Path $dst "data\map\assistant.js") `
  'var ASSISTANT_ENDPOINT = "https://pophealthmapai.sevilleharvey.workers.dev";' `
  $endpointNote.TrimEnd() `
  "assistant.js -> endpoint blanked"

# A CNAME here would make this mirror redirect to pophealth.uk, which is the
# one thing it must never do.
$cname = Join-Path $dst "CNAME"
if (Test-Path $cname) { throw "CNAME found in the mirror. Delete it: it would redirect this copy to pophealth.uk and defeat the whole point." }

$mb = (Get-ChildItem $dst -Recurse -File | Where-Object { $_.FullName -notmatch '\\\.git\\' } | Measure-Object Length -Sum).Sum / 1MB
Write-Host ""
Write-Host ("Synced {0} files, {1:N1} MB." -f $copied, $mb)
Write-Host "Now: git add -A; git commit -m 'Refresh mirror'; git push"
