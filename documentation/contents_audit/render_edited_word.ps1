$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$reviewWord = New-Object -ComObject Word.Application
$reviewWord.Visible = $false
$reviewWord.DisplayAlerts = 0
try {
 $reviewPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'Contents_Edited.docx'
 $reviewDoc = $reviewWord.Documents.Open($reviewPath,$false,$true)
 $reviewDoc.ActiveWindow.View.Type = 3
 $reviewDoc.Repaginate()
 $pageCount = $reviewDoc.ComputeStatistics(2)
 $reviewDoc.ExportAsFixedFormat((Join-Path $PSScriptRoot 'edited_review.pdf'),17)
 for($pageIndex=1;$pageIndex -le $pageCount;$pageIndex++) {
  $bits = [byte[]]$reviewDoc.ActiveWindow.Panes.Item(1).Pages.Item($pageIndex).EnhMetaFileBits
  $stream = [IO.MemoryStream]::new($bits,0,$bits.Length)
  $meta = [Drawing.Imaging.Metafile]::new($stream)
  $bitmap = [Drawing.Bitmap]::new(850,1100)
  $graphics = [Drawing.Graphics]::FromImage($bitmap)
  $graphics.Clear([Drawing.Color]::White)
  $graphics.DrawImage($meta,0,0,850,1100)
  $bitmap.Save((Join-Path $PSScriptRoot ('edited-page-{0:D2}.png' -f $pageIndex)),[Drawing.Imaging.ImageFormat]::Png)
  $graphics.Dispose();$bitmap.Dispose();$meta.Dispose();$stream.Dispose()
 }
 Write-Output "Rendered $pageCount pages for review."
 $reviewDoc.Close(0)
} finally {$reviewWord.Quit()}
