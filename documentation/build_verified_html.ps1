$ErrorActionPreference = 'Stop'
$sourcePath = Join-Path $PSScriptRoot 'DefendIt_Verified_Guide.md'
$outputPath = Join-Path $PSScriptRoot 'DefendIt_Verified_Guide.html'
$content = [IO.File]::ReadAllText($sourcePath)

function Convert-Inline([string]$value) {
    $escaped = [System.Net.WebUtility]::HtmlEncode($value)
    return [regex]::Replace($escaped, '`([^`]+)`', '<code>$1</code>')
}

$html = [Text.StringBuilder]::new()
[void]$html.AppendLine(@'
<!DOCTYPE html>
<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word" lang="en">
<head><meta charset="utf-8"><title>DefendIt System Guide and Documentation</title>
<style>
@page WordSection1 { size:8.5in 11in; margin:0.55in 0.65in 0.55in 0.65in; }
body { font-family:"Century Gothic",sans-serif; font-size:11pt; color:#000; line-height:1.04; }
.WordSection1 { page:WordSection1; }
h1,h2,h3 { font-family:"Century Gothic",sans-serif; color:#000; page-break-after:avoid; }
h1 {font-size:17pt;margin:0 0 5pt;} h2 {font-size:13pt;margin:8pt 0 5pt;} h3 {font-size:11pt;margin:6pt 0 3pt;}
p {margin:0 0 5pt;orphans:2;widows:2;}
table {width:100%;border-collapse:collapse;table-layout:fixed;margin:5pt 0 7pt;font-size:11pt;}
th,td {border:0.5pt solid #D9D9D9;padding:4pt 5pt;vertical-align:middle;overflow-wrap:anywhere;}
th {background:#E5EAF0;text-align:left;font-weight:bold;}
thead {display:table-header-group;} tr {page-break-inside:avoid;}
code {font-family:"Century Gothic",sans-serif;font-size:11pt;}
ol {margin:2pt 0 6pt;padding-left:18pt;} li {margin:0 0 4pt;}
.pagebreak {page-break-before:always;}
.folio {font-size:9pt;margin:0 0 5pt;text-align:right;color:#444;}
@media screen {body {background:#e8e8e8;margin:0;} .sheet {background:white;width:7.2in;min-height:9.9in;margin:16px auto;padding:0.55in 0.65in;box-shadow:0 1px 6px #aaa;} }
@media print {.sheet {margin:0;padding:0;} }
</style></head><body><div class="WordSection1">
'@)
$pages = $content -split '===PAGE==='
for ($pageIndex = 0; $pageIndex -lt $pages.Count; $pageIndex++) {
    $pageClass = if ($pageIndex -gt 0) {'sheet pagebreak'} else {'sheet'}
    [void]$html.AppendLine('<div class="' + $pageClass + '">')
    [void]$html.AppendLine('<p class="folio">DefendIt &nbsp; | &nbsp; ' + ($pageIndex + 1) + '</p>')
    $lines = $pages[$pageIndex].Trim() -split '\r?\n'
    $ordered = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].Trim()
        if (!$line) { continue }
        if ($ordered -and $line -notmatch '^\d+\. ') { [void]$html.AppendLine('</ol>'); $ordered = $false }
        if ($line.StartsWith('|')) {
            $rows = [Collections.Generic.List[object]]::new()
            while ($i -lt $lines.Count -and $lines[$i].Trim().StartsWith('|')) {
                $cells = $lines[$i].Trim().Trim('|').Split('|') | ForEach-Object {$_.Trim()}
                if ($cells[0] -notmatch '^[-:]+$') {$rows.Add($cells)}
                $i++
            }
            $i--
            $count = $rows[0].Count
            $widths = switch ($count) {2 {@(30,70)} 3 {@(23,28,49)} 4 {@(9,16,36,39)}}
            if ($rows[0][0] -eq 'Screen') {$widths = @(17,24,32,27)}
            if ($rows[0][0] -in @('Login and onboarding','Groups and title details')) {$widths = @(33,34,33)}
            [void]$html.AppendLine('<table><colgroup>')
            foreach ($width in $widths) {[void]$html.AppendLine('<col style="width:' + $width + '%">')}
            [void]$html.AppendLine('</colgroup><thead>')
            for ($r = 0; $r -lt $rows.Count; $r++) {
                if ($r -eq 1) {[void]$html.AppendLine('</thead><tbody>')}
                [void]$html.AppendLine('<tr>')
                $tag = if ($r -eq 0) {'th'} else {'td'}
                foreach ($cell in $rows[$r]) { [void]$html.AppendLine('<' + $tag + '>' + (Convert-Inline $cell) + '</' + $tag + '>') }
                [void]$html.AppendLine('</tr>')
            }
            [void]$html.AppendLine('</tbody></table>')
        } elseif ($line -match '^(#{1,3}) (.+)$') {
            $level = $Matches[1].Length
            [void]$html.AppendLine('<h' + $level + '>' + (Convert-Inline $Matches[2]) + '</h' + $level + '>')
        } elseif ($line -match '^\d+\. (.+)$') {
            if (!$ordered) {[void]$html.AppendLine('<ol>');$ordered = $true}
            [void]$html.AppendLine('<li>' + (Convert-Inline $Matches[1]) + '</li>')
        } else {
            [void]$html.AppendLine('<p>' + (Convert-Inline $line) + '</p>')
        }
    }
    if ($ordered) {[void]$html.AppendLine('</ol>')}
    [void]$html.AppendLine('</div>')
}
[void]$html.AppendLine('</div></body></html>')
[IO.File]::WriteAllText($outputPath,$html.ToString(),[Text.UTF8Encoding]::new($false))
$words = ($content -split '\s+' | Where-Object {$_ -match '\w'}).Count
Write-Output "Created $outputPath with $($pages.Count) planned pages and $words source words."
