$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression
$root=$PSScriptRoot
$teal='#176B63';$indigo='#176B63';$ink='#263238'
function Color($s){[Drawing.ColorTranslator]::FromHtml($s)}
function Font($size,$bold=$false){$style=if($bold){[Drawing.FontStyle]::Bold}else{[Drawing.FontStyle]::Regular};[Drawing.Font]::new('Century Gothic',[single]$size,$style,[Drawing.GraphicsUnit]::Pixel)}
function Rect($g,$x,$y,$w,$h,$fill,$border='#D9D9D9'){$b=[Drawing.SolidBrush]::new((Color $fill));$g.FillRectangle($b,$x,$y,$w,$h);$b.Dispose();$p=[Drawing.Pen]::new((Color $border),2);$g.DrawRectangle($p,$x,$y,$w,$h);$p.Dispose()}
function Text($g,$s,$x,$y,$w,$h,$size=25,$bold=$false,$color='#263238'){$f=Font $size $bold;$b=[Drawing.SolidBrush]::new((Color $color));$g.DrawString($s,$f,$b,[Drawing.RectangleF]::new($x,$y,$w,$h));$f.Dispose();$b.Dispose()}
function Canvas($w,$h){$b=[Drawing.Bitmap]::new($w,$h);$b.SetResolution(200,200);$g=[Drawing.Graphics]::FromImage($b);$g.SmoothingMode='AntiAlias';$g.TextRenderingHint='AntiAliasGridFit';$g.Clear([Drawing.Color]::White);return @($b,$g)}
$screens=@(
 @{id='41';title='DefendIt';sub='Every consultation, every action item, every milestone.';items=@('Thesis Consultation and Milestone Tracker','Google account authentication • no password form');button='Continue with Google'},
 @{id='42';title='How will you use DefendIt?';sub='Choose your role once.';items=@('Adviser — one-time access code','Student — book and track milestones','Student number: 2022-102420','Teammate code (optional)');button='Continue'},
 @{id='43';title='Today';sub='Good morning, Ana';items=@('NEXT CONSULTATION | 9:00–9:30 AM','Team Alpha | Engr. Reyes','Groups 1 | Booked 2 | To book 5','NEEDS ATTENTION','1 milestone needs revision','1 title idea needs polish');button='Today   Schedule   Groups   Progress'},
 @{id='44';title='Title ideas';sub='Team Alpha | Engr. Reyes';items=@('Smart attendance using rotating QR codes','Description: verifies attendance offline','Purpose: reduce buddy signing','APPROVED | Clear and feasible','Event check-in for student organizations','NEEDS POLISH | Narrow the scope');button='+ Add title idea'},
 @{id='45';title='Group request';sub='Smart attendance using rotating QR codes';items=@('Group: Team Alpha | Section: BSCpE 4-1','Topic: attendance system for events','Roster: Ana Cruz, Ben Lim, Carla Reyes, Dan Uy','PROPOSED TITLES','1  Smart attendance using rotating QR codes','2  Event check-in for student organizations');button='Accept group'},
 @{id='46';title='Milestone';sub='Chapter 1 Introduction | In progress';items=@('3 of 5 tasks done (60%) | Due Nov 5','Finish the remaining 2 tasks to submit','TEAM WORKLOAD','Ana Cruz 2/2 | Ben Lim 1/2 | Carla Reyes 0/1','TASKS','Draft survey questions | Ben Lim','Completed: background of the study');button='+ Add task'}
)
foreach($screen in $screens){$c=Canvas 800 1050;$b=$c[0];$g=$c[1];Rect $g 8 8 784 1034 '#F8F8F5' '#90979B';Rect $g 25 25 750 180 '#176B63' '#176B63';Text $g $screen.title 50 48 700 110 45 $true '#FFFFFF';Text $g $screen.sub 50 148 700 50 23 $false '#FFFFFF';$y=235;$count=$screen.items.Count;$step=if($count -gt 5){91}else{125};foreach($item in $screen.items){Rect $g 40 $y 720 ($step-15) '#FFFFFF';Text $g $item 58 ($y+12) 680 ($step-27) 26;$y+=$step};Rect $g 50 920 700 76 '#176B63' '#176B63';Text $g $screen.button 70 940 660 56 27 $true '#FFFFFF';$b.Save((Join-Path $root ($screen.id+'.png')),[Drawing.Imaging.ImageFormat]::Png);$g.Dispose();$b.Dispose()}
# Architecture figure preserves the source's layers and flows.
$c=Canvas 1500 920;$b=$c[0];$g=$c[1]
Rect $g 30 20 1440 185 '#F0F2FA' $indigo;Text $g 'PRESENTATION LAYER' 55 35 1390 50 35 $true $indigo;Text $g 'Flutter screens • Provider • go_router' 55 92 1390 45 29;Text $g 'Auth | Today | Groups | Titles | Schedule | Consultations | Milestones' 55 145 1390 40 25
Text $g '↓  delegate actions and observe results  ↑' 390 215 900 50 27
Rect $g 30 275 1440 160 '#F0F2FA' $indigo;Text $g 'REPOSITORY LAYER' 55 292 1390 50 35 $true $indigo;Text $g 'Validation • business rules • transactions' 55 350 1390 50 29
Text $g '↓ local records                         ↕ sync                         ↓ coordination' 90 445 1350 55 28
Rect $g 30 525 440 285 '#E3F1ED' $teal;Text $g 'LOCAL SQLITE' 50 545 400 50 32 $true $teal;Text $g "One file per user`nconsultations • action_items`ntitle_ideas • milestones`nmilestone_tasks • outbox" 50 610 400 180 25
Rect $g 530 525 440 285 '#FFF3DC' '#B7791F';Text $g 'SYNC SERVICE' 550 545 400 50 32 $true '#8C5700';Text $g "Push outbox oldest first`nPull Firestore listeners`nApply updatedAt policy`nPreserve pending local edits" 550 610 400 180 25
Rect $g 1030 525 440 285 '#F0F2FA' $indigo;Text $g 'FIREBASE CLOUD' 1050 545 400 50 32 $true $indigo;Text $g "Google Authentication`nCloud Firestore`nReal-time listeners`nSecurity Rules" 1050 610 400 180 25
Text $g 'SQLite  ↔  Sync Service  ↔  Firestore     |     Groups and booking use shared transactions' 45 850 1420 50 26
$b.Save((Join-Path $root 'architecture.png'),[Drawing.Imaging.ImageFormat]::Png);$g.Dispose();$b.Dispose()
# ERD uses only the source entities; named fields retain their exact identifiers.
$entities=@(
 @('users','text: uid, name, email; text?: photoUrl, role, studentNumber; writes: adviserCode (text), adviserGroupCount (int), createdAt (timestamp)'),
 @('groups','text: name, thesisTitle, code; text?: section, leaderUid, adviserUid, adviserName; list: memberUids, roster; map: memberNames; ms: createdAt'),
 @('slots','text: adviserUid, adviserName, status; text?: bookedGroupId, bookedGroupName, bookedByUid, bookedByName; ms: startsAt, createdAt; int: durationMins'),
 @('consultations','text: groupId, groupName, adviserUid, adviserName, notes; list: roster; ms: startsAt, createdAt, updatedAt; int: durationMins'),
 @('groups/{id}/titles','text: groupId, title, description, purpose, status, createdByUid, createdByName; text?: comment, reviewedByName; ms: createdAt, updatedAt; ms?: reviewedAt'),
 @('groups/{id}/milestones','text: groupId, slug, title, status; int: position; ms: updatedAt; ms?: dueAt; text?: comment, updatedByName'),
 @('groups/{id}/tasks','text: groupId, milestoneId, title, createdByName; text?: assignee, doneByName; bool: done; ms: createdAt, updatedAt; ms?: dueAt, doneAt'),
 @('actionItems','text: consultationId, groupId, groupName, adviserUid, title; text?: assignee; bool: done; ms: createdAt, updatedAt; ms?: dueAt, doneAt'),
 @('adviserCodes','Document ID: issued code; claimedByUid: text?; claimedAt: timestamp. Issued documents are provisioned externally.'),
 @('studentNumbers','Document ID: normalized number; uid: text; createdAt: timestamp. One owner per number through a registration transaction.')
)
$c=Canvas 1500 1400;$b=$c[0];$g=$c[1];for($i=0;$i -lt $entities.Count;$i++){$col=$i%2;$row=[Math]::Floor($i/2);$x=25+$col*750;$y=15+$row*252;Rect $g $x $y 700 230 '#F8F9FC' $indigo;Rect $g $x $y 700 51 $indigo $indigo;Text $g $entities[$i][0] ($x+15) ($y+8) 665 42 29 $true '#FFFFFF';Text $g $entities[$i][1] ($x+15) ($y+65) 665 157 26}
Text $g 'ms = integer epoch milliseconds; ? = nullable; document IDs are separate from payloads.' 25 1292 1450 45 26 $true
Text $g 'Group → titles / six milestones; milestone → tasks; booked slot → consultation → action items.' 25 1340 1450 45 25
$b.Save((Join-Path $root 'erd.png'),[Drawing.Imaging.ImageFormat]::Png);$g.Dispose();$b.Dispose()

function Esc([string]$s){[Security.SecurityElement]::Escape($s)}
function Run([string]$s,[string]$extra=''){return '<w:r><w:rPr>'+$extra+'</w:rPr><w:t xml:space="preserve">'+(Esc $s)+'</w:t></w:r>'}
function Para([string]$s,[string]$style='Normal'){return '<w:p><w:pPr><w:pStyle w:val="'+$style+'"/></w:pPr>'+(Run $s)+'</w:p>'}
function Table($rows,$widths,$borders=$true){
 $s='<w:tbl><w:tblPr><w:tblW w:w="10368" w:type="dxa"/><w:tblLayout w:type="fixed"/><w:tblCellMar><w:top w:w="20" w:type="dxa"/><w:left w:w="70" w:type="dxa"/><w:bottom w:w="20" w:type="dxa"/><w:right w:w="70" w:type="dxa"/></w:tblCellMar><w:tblBorders>'
 foreach($edge in @('top','left','bottom','right','insideH','insideV')){$s+='<w:'+$edge+' w:val="single" w:sz="4" w:color="D9D9D9"/>'};$s+='</w:tblBorders></w:tblPr><w:tblGrid>';foreach($w in $widths){$s+='<w:gridCol w:w="'+$w+'"/>'};$s+='</w:tblGrid>'
 for($r=0;$r -lt $rows.Count;$r++){$s+='<w:tr><w:trPr><w:cantSplit/>';if($r -eq 0){$s+='<w:tblHeader/>'};$s+='</w:trPr>';for($j=0;$j -lt $widths.Count;$j++){$fill=if($r -eq 0){'176B63'}elseif($r%2 -eq 0){'F2F5F4'}else{'FFFFFF'};$format=if($r -eq 0){'<w:b/><w:color w:val="FFFFFF"/>'}else{'<w:color w:val="263238"/>'};$s+='<w:tc><w:tcPr><w:tcW w:w="'+$widths[$j]+'" w:type="dxa"/><w:shd w:fill="'+$fill+'"/><w:vAlign w:val="center"/></w:tcPr><w:p><w:pPr><w:pStyle w:val="TableText"/></w:pPr>'+(Run $rows[$r][$j] $format)+'</w:p></w:tc>'};$s+='</w:tr>'};return $s+'</w:tbl>'
}
$script:imageId=0;$script:imageRels='';$script:media=@{}
function ImageXml($file,$width,$height){$script:imageId++;$id=$script:imageId;$rid='im'+$id;$name='fig'+$id+'.png';$script:media[$name]=$file;$script:imageRels+='<Relationship Id="'+$rid+'" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/'+$name+'"/>';$cx=[int]($width*914400);$cy=[int]($height*914400);return '<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="'+$cx+'" cy="'+$cy+'"/><wp:docPr id="'+$id+'" name="Figure '+$id+'"/><wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/></wp:cNvGraphicFramePr><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic><pic:nvPicPr><pic:cNvPr id="'+$id+'" name="'+$name+'"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="'+$rid+'"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="'+$cx+'" cy="'+$cy+'"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>'}
function PairXml($group){$ids=switch($group){entry{@('41','42')}work{@('43','44')}review{@('45','46')}};$captions=switch($group){entry{@('Figure 4.1 Login','Figure 4.2 Student registration')}work{@('Figure 4.3 Today dashboard','Figure 4.4 Title ideas')}review{@('Figure 4.5 Adviser preview','Figure 4.6 Milestone tasks')}};$height=if($group -eq 'entry'){2.85}else{4.45};$width=$height*800/1050;$s='<w:tbl><w:tblPr><w:tblW w:w="10368" w:type="dxa"/><w:tblBorders><w:top w:val="nil"/><w:left w:val="nil"/><w:bottom w:val="nil"/><w:right w:val="nil"/><w:insideH w:val="nil"/><w:insideV w:val="nil"/></w:tblBorders></w:tblPr><w:tblGrid><w:gridCol w:w="5184"/><w:gridCol w:w="5184"/></w:tblGrid><w:tr><w:trPr><w:cantSplit/></w:trPr>';for($k=0;$k -lt 2;$k++){$s+='<w:tc><w:tcPr><w:tcW w:w="5184" w:type="dxa"/></w:tcPr><w:p><w:pPr><w:jc w:val="center"/><w:spacing w:after="60"/></w:pPr>'+(ImageXml (Join-Path $root ($ids[$k]+'.png')) $width $height)+'</w:p>'+(Para $captions[$k] 'Caption')+'</w:tc>'};return $s+'</w:tr></w:tbl>'}
$source=[IO.File]::ReadAllText((Join-Path $root 'publication.md'))
$pages=$source -split '===PAGE==='
if($pages.Count -ne 12){throw 'Source must contain exactly 12 page units.'}
$body='';for($p=0;$p -lt $pages.Count;$p++){
 if($p -gt 0){$body+='<w:p><w:pPr><w:spacing w:before="0" w:after="0" w:line="20" w:lineRule="exact"/></w:pPr><w:r><w:br w:type="page"/></w:r></w:p>'}
 $lines=$pages[$p].Trim() -split '\r?\n';for($i=0;$i -lt $lines.Count;$i++){$line=$lines[$i].Trim();if(!$line){continue}
 if($line.StartsWith('|')){$rows=[Collections.Generic.List[object]]::new();while($i -lt $lines.Count -and $lines[$i].Trim().StartsWith('|')){$cells=$lines[$i].Trim().Trim('|').Split('|')|ForEach-Object {$_.Trim()};if($cells[0] -notmatch '^[-:]+$'){$rows.Add($cells)};$i++};$i--;$widths=switch($rows[0].Count){2{@(2592,7776)}3{@(2160,3888,4320)}5{@(1450,1620,2430,2920,1948)}};if($rows[0][0] -eq 'Collection or document path'){$widths=@(4320,6048)};$body+=Table $rows $widths
 }elseif($line -match '^@PAIR (\w+)'){$body+=PairXml $Matches[1]
 }elseif($line -match '^@IMAGE (\w+)'){$kind=$Matches[1];$height=if($kind -eq 'architecture'){3.8}else{6.35};$width=if($kind -eq 'architecture'){6.2}else{6.8};$body+='<w:p><w:pPr><w:jc w:val="center"/><w:keepNext/><w:spacing w:before="60" w:after="30"/></w:pPr>'+(ImageXml (Join-Path $root ($kind+'.png')) $width $height)+'</w:p>'
 }elseif($line -match '^@CAPTION (.+)$'){$body+=Para $Matches[1] 'Caption'
 }elseif($line -match '^(#{1,3}) (.+)$'){$level=$Matches[1].Length;$style='Heading'+$level;$body+=Para $Matches[2] $style
 }elseif($line -match '^- (.+)$'){$body+=Para ('• '+$Matches[1]) 'ListText'
 }else{$style='Normal';$body+=Para $line $style}
 }
}
$styles='<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Century Gothic" w:hAnsi="Century Gothic" w:eastAsia="Century Gothic" w:cs="Century Gothic"/><w:color w:val="263238"/><w:sz w:val="22"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="276" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>'
foreach($spec in @(@('Normal',22,'263238',0),@('Heading1',36,'176B63',1),@('Heading2',28,'176B63',1),@('Heading3',24,'37474F',1),@('TableText',20,'263238',0),@('Caption',20,'37474F',0),@('ListText',22,'263238',0),@('Title',48,'000000',1),@('Subtitle',28,'176B63',1),@('CoverText',22,'263238',0))){$id=$spec[0];$styles+='<w:style w:type="paragraph" w:styleId="'+$id+'"><w:name w:val="'+$id+'"/><w:basedOn w:val="Normal"/><w:qFormat/><w:pPr>'
if($id -like 'Heading*'){$level=[int]$id.Substring(7)-1;$styles+='<w:keepNext/><w:keepLines/><w:outlineLvl w:val="'+$level+'"/><w:spacing w:before="80" w:after="60" w:line="276" w:lineRule="auto"/>'}
if($id -eq 'TableText'){$styles+='<w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/>'}
if($id -eq 'Caption'){$styles+='<w:jc w:val="center"/><w:spacing w:before="30" w:after="120"/>'}
if($id -eq 'ListText'){$styles+='<w:spacing w:after="60"/><w:ind w:left="220" w:hanging="170"/>'}
if($id -in @('Title','Subtitle','CoverText')){$styles+='<w:jc w:val="center"/>';if($id -eq 'Title'){$styles+='<w:spacing w:before="1700" w:after="240"/>'}elseif($id -eq 'CoverText'){$styles+='<w:spacing w:before="160" w:after="200"/>'}}
$styles+='</w:pPr><w:rPr><w:rFonts w:ascii="Century Gothic" w:hAnsi="Century Gothic" w:eastAsia="Century Gothic" w:cs="Century Gothic"/><w:sz w:val="'+$spec[1]+'"/><w:color w:val="'+$spec[2]+'"/>';if($spec[3]){$styles+='<w:b/>'};if($id -eq 'Caption'){$styles+='<w:i/>'};$styles+='</w:rPr></w:style>'};$styles+='</w:styles>'
$document='<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><w:body>'+$body+'<w:sectPr><w:footerReference w:type="default" r:id="footer"/><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="864" w:right="936" w:bottom="864" w:left="936" w:header="360" w:footer="360"/></w:sectPr></w:body></w:document>'
$parts=@{
'[Content_Types].xml'='<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/><Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/></Types>';
'_rels/.rels'='<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="document" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>';
'word/document.xml'=$document;
'word/styles.xml'=$styles;
'word/_rels/document.xml.rels'='<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="styles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/><Relationship Id="footer" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>'+$script:imageRels+'</Relationships>';
'word/footer1.xml'='<?xml version="1.0" encoding="UTF-8"?><w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii="Century Gothic" w:hAnsi="Century Gothic"/><w:sz w:val="20"/></w:rPr><w:t>DefendIt  |  </w:t></w:r><w:fldSimple w:instr="PAGE"><w:r><w:rPr><w:rFonts w:ascii="Century Gothic" w:hAnsi="Century Gothic"/><w:sz w:val="20"/></w:rPr><w:t>1</w:t></w:r></w:fldSimple></w:p></w:ftr>'
}
$out=Join-Path $root 'DefendIt_Repository_Verified.docx';$fs=[IO.File]::Create($out);$zip=[IO.Compression.ZipArchive]::new($fs,'Create');foreach($name in $parts.Keys){$e=$zip.CreateEntry($name);$s=$e.Open();$bytes=[Text.UTF8Encoding]::new($false).GetBytes($parts[$name]);$s.Write($bytes,0,$bytes.Length);$s.Dispose()};foreach($name in $script:media.Keys){$e=$zip.CreateEntry('word/media/'+$name);$s=$e.Open();$bytes=[IO.File]::ReadAllBytes($script:media[$name]);$s.Write($bytes,0,$bytes.Length);$s.Dispose()};$zip.Dispose();$fs.Dispose();Write-Output "Built $out with $($pages.Count) page units."
