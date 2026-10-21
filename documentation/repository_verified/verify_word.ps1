$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$word=[Runtime.InteropServices.Marshal]::GetActiveObject('Word.Application')
$word.DisplayAlerts=0
Write-Output 'Connected to Word.'
$path=Join-Path $PSScriptRoot 'DefendIt_Repository_Verified.docx'
$doc=$null
try {
 $doc=$word.Documents.Open($path,$false,$true)
 Write-Output 'Opened publication read-only.'
 $doc.ActiveWindow.View.Type=3
 $doc.Repaginate()
 $count=$doc.ComputeStatistics(2)
 Write-Output ('WORD_PAGE_COUNT='+$count)
 $pdf=Join-Path $PSScriptRoot 'DefendIt_Repository_Verified.pdf'
 # PDF export follows page-image rendering.

 for($i=1;$i -le $count;$i++) {
  $page=$doc.ActiveWindow.Panes.Item(1).Pages.Item($i)
  $bits=[byte[]]$page.EnhMetaFileBits
  $stream=[IO.MemoryStream]::new($bits,0,$bits.Length)
  $meta=[Drawing.Imaging.Metafile]::new($stream)
  $bitmap=[Drawing.Bitmap]::new(1275,1650)
  $graphics=[Drawing.Graphics]::FromImage($bitmap)
  $graphics.Clear([Drawing.Color]::White)
  $graphics.DrawImage($meta,0,0,1275,1650)
  $bitmap.Save((Join-Path $PSScriptRoot ('page-{0:D2}.png' -f $i)),[Drawing.Imaging.ImageFormat]::Png)
  $graphics.Dispose();$bitmap.Dispose();$meta.Dispose();$stream.Dispose()
 }
 Write-Output "Rendered all $count pages."
 [object]$pdfObject=[string]$pdf; [object]$formatObject=[int]17; $doc.SaveAs([ref]$pdfObject,[ref]$formatObject)
 Write-Output ('PDF='+$pdf)
} finally {if($doc){$doc.Close(0)}}
