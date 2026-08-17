<#
  Refresh this mirror from the main repo.

  The mirror is a copy of the files pophealth.uk serves, nothing else: no
  pipeline, no parquet, no history. One file differs from the original on
  purpose, and this script reapplies that difference after every copy so it
  cannot be lost in a refresh:

    index.html            robots meta becomes noindex

  The patch fails loudly if the text it expects is missing, which is the point:
  if the main repo changes that line, this stops rather than quietly publishing
  an indexable copy.

  data/map/assistant.js is copied across unchanged. The Worker's
  ALLOWED_ORIGINS already lists https://harv334.github.io, so the Ask panel
  works here exactly as it does on the live site.

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
  "ward_data.json", "lsoa_data.json", "msoa_data.json", "borough_data.json",
  "vcse_data.json", "cics.json",
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

# The two halves of the ward data. index.html asks for data/ward_core.json
# first and falls back to the whole ward_data.json above, so a mirror without
# these still draws the right map. It just spends a 404 on every load and then
# waits for 419.5 KB instead of 264.9 KB. Named rather than swept up with a
# wildcard: everything else under data\ is boundaries and parquet that this
# copy does not serve.
foreach ($f in @("ward_core.json", "ward_rest.json")) {
  $from = Join-Path $Source "data\$f"
  if (-not (Test-Path $from)) { Write-Warning "missing in source, skipped: data\$f"; continue }
  Copy-Item $from (Join-Path $dst "data\$f") -Force
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

# A CNAME here would make this mirror redirect to pophealth.uk, which is the
# one thing it must never do.
$cname = Join-Path $dst "CNAME"
if (Test-Path $cname) { throw "CNAME found in the mirror. Delete it: it would redirect this copy to pophealth.uk and defeat the whole point." }

$mb = (Get-ChildItem $dst -Recurse -File | Where-Object { $_.FullName -notmatch '\\\.git\\' } | Measure-Object Length -Sum).Sum / 1MB
Write-Host ""
Write-Host ("Synced {0} files, {1:N1} MB." -f $copied, $mb)
Write-Host "Now: git add -A; git commit -m 'Refresh mirror'; git push"
