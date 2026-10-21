$guideWord = New-Object -ComObject Word.Application
$guideWord.Visible = $false
$guideWord.DisplayAlerts = 0
try {
    $guidePath = Join-Path $PSScriptRoot 'DefendIt_System_Guide.docx'
    $guidePdf = Join-Path $PSScriptRoot 'qa\DefendIt_System_Guide_final.pdf'
    $guideDoc = $guideWord.Documents.Open($guidePath, $false, $true)
    $guideDoc.Repaginate()
    Write-Output ('Pages: ' + $guideDoc.ComputeStatistics(2))
    $guideDoc.SaveAs2($guidePdf, 17)
    $guideDoc.Close(0)
} finally {
    $guideWord.Quit()
}
