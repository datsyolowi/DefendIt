$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
$source = 'C:/Users/Lorie/Downloads/Contents.docx'
$output = Join-Path (Split-Path $PSScriptRoot -Parent) 'Contents_Edited_Final.docx'
$inputStream = [IO.File]::Open($source,'Open','Read','ReadWrite')
$zip = [IO.Compression.ZipArchive]::new($inputStream,'Read')
$reader = [IO.StreamReader]::new($zip.GetEntry('word/document.xml').Open())
$originalXml = $reader.ReadToEnd(); $reader.Dispose()
$xml = [xml]::new(); $xml.PreserveWhitespace = $true; $xml.LoadXml($originalXml)
$ns = [Xml.XmlNamespaceManager]::new($xml.NameTable)
$ns.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main')
$paragraphs = $xml.SelectNodes('//w:body//w:p',$ns)
$edits = @(
 @("members book their group's adviser", "members book available consultation slots with their group's adviser"),
 @('booking and other transactional operations require a connection','booking, registration, and group membership changes require a connection'),
 @('Student Leader and Teammate share','Student Leader and team members share'),
 @('register a number, and leave teammate code empty','register a student number, and leave the teammate code empty when creating a group'),
 @('Consultation methods rely on UI restrictions and backend rules rather than actor guards.','Consultation methods rely on UI restrictions and backend rules rather than explicit user-permission checks in the repository.'),
 @('map to the teal values below','map to #176B63, #103C3B, and #E3F1ED, respectively'),
 @('Displays greetings for user Lorie','Displays a greeting for the signed-in user (Lorie in the screenshot)'),
 @('Displays user Lors with a Student badge','Displays the signed-in user (Lors in the screenshot) with a Student badge'),
 @('Shows state for unassigned students','Shows the state for students without a group'),
 @('Displays empty state','Displays an empty state'),
 @('Initial state informing users','Displays an initial state informing users'),
 @('Shows breakdown of thesis progress','Shows a breakdown of thesis progress'),
 @('1 of 1 tasks done','1 of 1 task done'),
 @('Itemizes sequential milestones including:','Shows milestones in display order.'),
 @('20-pixel card radii, 14-pixel input and primary-button radii, and 28-pixel upper sheet corners','20-logical-pixel card radii, 14-logical-pixel input and primary-button radii, and 28-logical-pixel upper sheet corners'),
 @('Keep these controls and explanations visible in the corresponding layouts rather than exposing unavailable actions to the wrong role.','The corresponding layouts show these controls and explanations, with actions restricted by role.'),
 @('approved counts as 1; otherwise completed tasks divided by total tasks counts, with zero for no tasks','an approved milestone counts as 1; otherwise, its completion value is completed tasks divided by total tasks, or zero when it has no tasks'),
 @('Remote workflow: Outbox ordered by seq','Remote upload: Outbox ordered by seq'),
 @('Firestore listeners → model conversion','Remote download: Firestore listeners → model conversion'),
 @('legacy milestone seeding','initializing milestones for older groups'),
 @('No usable application session, or profile loading failed.','No signed-in user, or profile loading failed despite Firebase authentication.'),
 @('Each mirrored SQLite table adds id TEXT PRIMARY KEY to the Firestore payload.','Each mirrored SQLite table stores the Firestore payload fields and adds an id column declared as TEXT PRIMARY KEY.'),
 @('older empty groups can be seeded online','older groups without milestones can have their default milestones created online'),
 @('No title-edit workflow exists.','No workflow for editing the action-item title exists.'),
 @('Backend permissions therefore require separate configuration and integration testing.','Backend permissions therefore require separate configuration and integration testing.'),
 @('Enable and test the deployed Firestore rules.','Configure and test the Firestore rules in the Firebase console; this project does not include a deployable rules file.'),
 @('from the project root when regenerating this configuration.','from the project root when regenerating this configuration. If using a separate Firebase project, substitute its project ID in the command.'),
 @('Run flutter test after adding applicable automated tests; flutter_test is declared, but a dependency declaration does not prove test coverage.','The flutter_test dependency is declared, but no runnable test suite is identified here. After adding automated tests, run flutter test.'),
 @('receives the implemented error message','receives a message stating that sign-in was canceled or the app configuration needs checking'),
 @('Delete a pending title; attempt deletion after approval.','Delete a pending title; attempt to delete a separate approved title.'),
 @('Action-item CRUD','Action-item creation, completion, and deletion'),
 @('Local edit and queued operation remain available for the same account.','Local edit remains available for the same account; inspect its SQLite outbox to confirm the queued operation persists.'),
 @('Interrupt service access while a write is queued.','Queue an offline edit, then reconnect with Firestore access blocked.'),
 @('Accounts use different SQLite files; original local data remains with its UID.','Each account sees only its own local records; returning restores the original account data. Inspect database filenames to confirm separate UID-based files.')
)
$changed = 0
foreach ($edit in $edits) {
 $old = $edit[0]; $new = $edit[1]
 if ($old -eq $new) {continue}
 $found = 0
 foreach ($p in $paragraphs) {
  $nodes = @($p.SelectNodes('.//w:t',$ns))
  $text = ($nodes | ForEach-Object {$_.InnerText}) -join ''
  $at = $text.IndexOf($old,[StringComparison]::Ordinal)
  if ($at -lt 0) {continue}
  $found++
  $end = $at + $old.Length
  $offset = 0
  foreach ($node in $nodes) {
   $value = $node.InnerText; $nodeEnd = $offset + $value.Length
   if ($nodeEnd -gt $at -and $offset -lt $end) {
    $localStart = [Math]::Max(0,$at-$offset)
    $localEnd = [Math]::Min($value.Length,$end-$offset)
    $insert = if($at -ge $offset -and $at -lt $nodeEnd){$new}else{''}
    $node.InnerText = $value.Substring(0,$localStart) + $insert + $value.Substring($localEnd)
    [void]$node.SetAttribute('space','http://www.w3.org/XML/1998/namespace','preserve')
   }
   $offset = $nodeEnd
  }
 }
 if ($found -ne 1) {throw "Expected one match for: $old; found $found"}
 $changed++
}
# Keep heading wording, numbering, table headers, and all images unchanged.
$outputStream = [IO.File]::Create($output)
$outZip = [IO.Compression.ZipArchive]::new($outputStream,'Create')
foreach($entry in $zip.Entries) {
 $newEntry = $outZip.CreateEntry($entry.FullName,[IO.Compression.CompressionLevel]::Optimal)
 $dest = $newEntry.Open()
 if ($entry.FullName -eq 'word/document.xml') {
  $settings=[Xml.XmlWriterSettings]::new(); $settings.Encoding=[Text.UTF8Encoding]::new($false); $settings.CloseOutput=$false
  $writer=[Xml.XmlWriter]::Create($dest,$settings);$xml.Save($writer);$writer.Dispose()
 } else {$src=$entry.Open();$src.CopyTo($dest);$src.Dispose()}
 $dest.Dispose()
}
$outZip.Dispose();$outputStream.Dispose();$zip.Dispose();$inputStream.Dispose()
Write-Output "Saved $output with $changed wording corrections."
