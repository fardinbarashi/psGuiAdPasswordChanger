<#
.SYNOPSIS
    Builds a self-contained HTML password report for one OU.
.DESCRIPTION
    * Logo embedded as base64 (portable single file).
    * Stat cards for Changed / Failed.
    * Quick filter buttons: Active, Inactive, Locked, PW Expired, PW never expires.
    * Free-text search box, Changed / Failed tabs.
    * Columns: Name, Account, State (account status tags), PW.
    * Rows use rotating soft colours (columns stay uncoloured); hover makes the
      row text bold and changes the row background.
#>
function New-HtmlReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$OuName,   # OU name
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]]$Results,
        [string]$LogoPath = (Join-Path $script:App.Root 'asset\logo\logo.png'),
        [bool]$WhatIf = $true,
        [bool]$OptionsOnly = $false
    )

    if (-not ('System.Web.HttpUtility' -as [type])) {
        try { Add-Type -AssemblyName System.Web -ErrorAction Stop } catch { }
    }
    function Enc([string]$s) {
        if ($null -eq $s) { return '' }
        if ('System.Web.HttpUtility' -as [type]) { return [System.Web.HttpUtility]::HtmlEncode($s) }
        return ($s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;')
    }

    $logoTag = ''
    if (Test-Path $LogoPath) {
        try {
            $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($LogoPath))
            $logoTag = "<img class='logo' src='data:image/png;base64,$b64' alt='logo'/>"
        } catch { }
    }

    $changed = @($Results | Where-Object { $_.State -in @('OK','WHATIF') })
    $skipped = @($Results | Where-Object { $_.State -eq 'FAILED' })

    function New-StatusHtml([object]$r) {
        $parts = @()
        if ($r.Enabled) { $parts += "<span class='tag ok'>Active</span>" }
        else            { $parts += "<span class='tag bad'>Disabled</span>" }
        if ($r.LockedOut)     { $parts += "<span class='tag bad'>Locked</span>" }
        if ($r.PSObject.Properties['PasswordExpired'] -and $r.PasswordExpired) {
            $parts += "<span class='tag bad'>PW Expired</span>"
        }
        elseif ($r.PSObject.Properties['PasswordExpiryDate'] -and $r.PasswordExpiryDate) {
            $parts += ("<span class='tag info'>PW Expire: {0}</span>" -f $r.PasswordExpiryDate.ToString('yyyy-MM-dd'))
        }
        if ($r.PasswordNeverExpires) { $parts += "<span class='tag muted'>PW never expires</span>" }
        if ($r.PSObject.Properties['AccountExpired'] -and $r.AccountExpired) {
            $parts += "<span class='tag bad'>Account Expired</span>"
        }
        elseif ($r.PSObject.Properties['AccountExpiryDate'] -and $r.AccountExpiryDate) {
            $parts += ("<span class='tag info'>Account Expire: {0}</span>" -f $r.AccountExpiryDate.ToString('yyyy-MM-dd'))
        }
        return ($parts -join ' ')
    }

    function New-Rows([object[]]$rows) {
        $sorted = $rows | Sort-Object Name
        $sb = New-Object System.Text.StringBuilder
        $i = 0
        foreach ($r in $sorted) {
            $tone = 'tone' + ($i % 5); $i++
            $active = if ($r.Enabled) { '1' } else { '0' }
            $locked = if ($r.LockedOut) { '1' } else { '0' }
            $pne    = if ($r.PasswordNeverExpires) { '1' } else { '0' }
            $pwexp  = if ($r.PSObject.Properties['PasswordExpired'] -and $r.PasswordExpired) { '1' } else { '0' }
            $hay = (@($r.Name,$r.Account) -join ' ').ToLower()

            # Rows from an account-options run carry no password - show that plainly
            # instead of a masked value nobody can reveal.
            $pwChanged = if ($r.PSObject.Properties['PasswordChanged']) { [bool]$r.PasswordChanged } else { $true }
            $pwCell = if ($pwChanged) {
                "<code class='pw' data-pw=""$(Enc $r.Password)"">&#8226;&#8226;&#8226;&#8226;&#8226;&#8226;&#8226;&#8226;</code><button type='button' class='pwbtn rowpw'>show</button>"
            } else {
                "<span class='nochange'>- not changed -</span>"
            }
            $optCell = if ($r.PSObject.Properties['Options'] -and $r.Options) {
                (($r.Options -split ',\s*') | ForEach-Object { "<span class='tag muted'>$(Enc $_)</span>" }) -join ' '
            } else { '' }

            [void]$sb.AppendLine(@"
      <tr class='row $tone' data-active='$active' data-locked='$locked' data-pne='$pne' data-pwexpired='$pwexp' data-search='$(Enc $hay)'>
        <td class='c-name'>$(Enc $r.Name)</td>
        <td class='c-acct'>$(Enc $r.Account)</td>
        <td class='c-state'>$(New-StatusHtml $r)</td>
        <td class='c-opt'>$optCell</td>
        <td class='c-pw'>$pwCell</td>
      </tr>
"@)
        }
        return $sb.ToString()
    }

    $changedRows = New-Rows $changed
    $skippedRows = New-Rows $skipped
    $generated   = Get-Date -Format 'yyyy-MM-dd HH:mm'
    $whatIfText  = if ($OptionsOnly) { 'TEST MODE / What-if &mdash; no account options were actually written' }
                   else             { 'TEST MODE / What-if &mdash; no passwords were actually changed' }
    $modeBanner  = if ($WhatIf) { "<div class='mode'>$whatIfText</div>" } else { '' }
    if ($OptionsOnly -and -not $WhatIf) {
        $modeBanner = "<div class='mode'>ACCOUNT OPTIONS ONLY &mdash; no passwords were changed</div>"
    }
    $reportTitle  = if ($OptionsOnly) { 'Account options report' } else { 'PW report' }
    $ver          = if ($script:App.Version) { $script:App.Version } else { Get-AppVersion }
    $verText      = 'psGuiAdPasswordChanger v{0}' -f $ver.VersionLabel
    $footText     = if ($ver.Link) { "$(Enc $verText) - <a href='$(Enc $ver.Link)'>$(Enc $ver.Link)</a>" } else { Enc $verText }
    $changedLabel = if ($OptionsOnly) {
        if ($WhatIf) { 'Would update' } else { 'Options updated' }
    }
    elseif ($WhatIf) { 'Would change' }
    else             { 'PW changed' }

    $html = @"
<!DOCTYPE html>
<html lang='sv'>
<head>
<meta charset='utf-8'/>
<meta name='viewport' content='width=device-width, initial-scale=1'/>
<title>$reportTitle - $(Enc $OuName)</title>
<style>
  :root{--blue:#1e76be;--blue2:#175c96;--ink:#1f2a37;--muted:#6b7280;--line:#e6ebf1;--ok:#16a34a;--warn:#d97706;--fail:#dc2626;}
  *{box-sizing:border-box}
  body{margin:0;font-family:Segoe UI,Roboto,Helvetica,Arial,sans-serif;background:#eef2f7;color:var(--ink);padding:24px}
  .wrap{max-width:1100px;margin:0 auto}
  .header{background:linear-gradient(135deg,var(--blue),var(--blue2));color:#fff;border-radius:18px;padding:26px 30px;box-shadow:0 8px 24px rgba(23,92,150,.25)}
  .brand{display:flex;align-items:center;gap:10px;background:#fff;padding:7px 14px;border-radius:10px;width:max-content}
  .brand .logo{height:26px;width:26px}
  .brand span{font-weight:700;color:var(--blue);font-size:15px}
  .header h1{margin:14px 0 4px;font-size:28px}
  .header .sub{opacity:.85;font-size:14px}
  .header .note{margin-top:10px;font-size:13px;opacity:.9}
  .mode{margin-top:12px;background:rgba(255,255,255,.18);border:1px solid rgba(255,255,255,.35);padding:6px 12px;border-radius:8px;font-size:13px;width:max-content}
  .cards{display:grid;grid-template-columns:1fr 1fr;gap:18px;margin:18px 0}
  .card{background:#fff;border-radius:16px;padding:22px 24px;box-shadow:0 2px 8px rgba(0,0,0,.05)}
  .card .num{font-size:40px;font-weight:800;line-height:1}
  .card.green .num{color:var(--ok)} .card.orange .num{color:var(--warn)} .card.red .num{color:var(--fail)}
  .card .lbl{color:var(--muted);margin-top:6px}
  .controls{background:#fff;border-radius:14px;padding:14px 16px;box-shadow:0 2px 8px rgba(0,0,0,.05);display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin-bottom:14px}
  .controls input[type=text]{flex:1;min-width:220px;padding:10px 14px;border:1px solid var(--line);border-radius:10px;font-size:14px}
  .qbtns{display:flex;gap:6px;flex-wrap:wrap}
  .chip{border:1px solid var(--line);background:#f8fafc;border-radius:999px;padding:7px 14px;font-size:13px;cursor:pointer;user-select:none;transition:all .12s}
  .chip:hover{border-color:var(--blue)}
  .chip.on{background:var(--blue);border-color:var(--blue);color:#fff;font-weight:600}
  .tabs{display:flex;gap:6px}
  .tab{padding:10px 18px;border:1px solid var(--line);border-bottom:none;background:#f3f6fa;border-radius:12px 12px 0 0;cursor:pointer;font-weight:600;color:var(--muted)}
  .tab.on{background:#fff;color:var(--blue)}
  .tablewrap{background:#fff;border-radius:0 14px 14px 14px;box-shadow:0 2px 8px rgba(0,0,0,.05);overflow:hidden}
  table{width:100%;border-collapse:collapse}
  thead th{text-align:left;font-size:12px;letter-spacing:.04em;text-transform:uppercase;color:var(--muted);padding:14px 16px;background:#fbfcfe;border-bottom:1px solid var(--line)}
  tbody td{padding:13px 16px;border-bottom:1px solid var(--line);font-size:14px}
  tr.tone0{background:#ffffff} tr.tone1{background:#f3f8ff} tr.tone2{background:#fef6f0} tr.tone3{background:#f2fbf4} tr.tone4{background:#f7f4fd}
  tbody tr.row:hover td{background:#dbeafe;font-weight:700}
  code{font-family:Consolas,Menlo,monospace;color:#0f7b3f;background:#eafaf0;padding:2px 8px;border-radius:6px}
  .pwbtn{margin-left:8px;font-size:11px;font-weight:600;padding:2px 9px;border:1px solid var(--line);border-radius:6px;background:#fff;color:var(--blue);cursor:pointer}
  .pwbtn:hover{border-color:var(--blue)}
  .pwbtn.on{background:var(--blue);border-color:var(--blue);color:#fff}
  thead th .pwbtn{text-transform:none;letter-spacing:0}
  .badge{font-size:12px;font-weight:700;padding:3px 9px;border-radius:999px}
  .badge.ok{color:#0f7b3f;background:#e7f8ee}
  .badge.whatif{color:#8a5a00;background:#fff2dc}
  .badge.failed{color:#a11;background:#fdeaea}
  .tag{font-size:11px;font-weight:700;padding:2px 8px;border-radius:6px;white-space:nowrap}
  .tag.bad{color:#b21c1c;background:#fdeaea}
  .tag.info{color:#8a5a00;background:#fff2dc}
  .tag.muted{color:#475569;background:#eef2f7}
  .tag.ok{color:#0f7b3f;background:#e7f8ee}
  .nochange{color:var(--muted);font-style:italic;font-size:13px}
  .c-opt .tag{margin-right:4px}
  .empty{padding:30px;text-align:center;color:var(--muted)}
  .foot{text-align:center;color:var(--muted);font-size:13px;margin:22px 0 6px}
  .hidden{display:none}
</style>
</head>
<body>
<div class='wrap'>
  <div class='header'>
    <div class='brand'>$logoTag<span>AD-PasswordChanger</span></div>
    <h1>$reportTitle - $(Enc $OuName)</h1>
    <div class='sub'>Generated $generated</div>
    $modeBanner
    <div class='note'>Handle passwords confidentially and send the report encrypted.</div>
  </div>

  <div class='cards'>
    <div class='card green'><div class='num'>$($changed.Count)</div><div class='lbl'>$changedLabel</div></div>
    <div class='card red'><div class='num'>$($skipped.Count)</div><div class='lbl'>Failed</div></div>
  </div>

  <div class='controls'>
    <input type='text' id='search' placeholder='Filter: name, account, password...'/>
    <div class='qbtns' id='status-filters'>
      <span class='chip' data-filter='active'>Active</span>
      <span class='chip' data-filter='inactive'>Inactive</span>
      <span class='chip' data-filter='locked'>Locked</span>
      <span class='chip' data-filter='pwexpired'>PW Expired</span>
      <span class='chip' data-filter='pne'>PW never expires</span>
    </div>
  </div>

  <div class='tabs'>
    <div class='tab on' data-tab='changed'>Changed ($($changed.Count))</div>
    <div class='tab' data-tab='failed'>Failed ($($skipped.Count))</div>
  </div>

  <div class='tablewrap'>
    <table id='tbl-changed'>
      <thead><tr><th>Name</th><th>Account</th><th>State</th><th>Options</th><th>PW <button type='button' class='pwbtn'>Show all</button></th></tr></thead>
      <tbody>
$changedRows
      </tbody>
    </table>
    <table id='tbl-failed' class='hidden'>
      <thead><tr><th>Name</th><th>Account</th><th>State</th><th>Options</th><th>PW <button type='button' class='pwbtn'>Show all</button></th></tr></thead>
      <tbody>
$skippedRows
      </tbody>
    </table>
    <div class='empty hidden' id='norows'>No rows match the current filter.</div>
  </div>

  <div class='foot'>$footText</div>

</div>

<script>
  var state = { tab:'changed', status:{active:false,inactive:false,locked:false,pwexpired:false,pne:false}, search:'' };
  function apply(){
    var table = document.getElementById('tbl-' + state.tab);
    var other = document.getElementById('tbl-' + (state.tab==='changed'?'failed':'changed'));
    table.classList.remove('hidden'); other.classList.add('hidden');
    var rows = table.querySelectorAll('tbody tr.row'); var visible = 0;
    rows.forEach(function(r){
      var ok = true; var st = state.status;
      if(st.active   && r.getAttribute('data-active')!=='1') ok=false;
      if(st.inactive && r.getAttribute('data-active')!=='0') ok=false;
      if(st.locked   && r.getAttribute('data-locked')!=='1') ok=false;
      if(st.pwexpired&& r.getAttribute('data-pwexpired')!=='1') ok=false;
      if(st.pne      && r.getAttribute('data-pne')!=='1')   ok=false;
      if(state.search && r.getAttribute('data-search').indexOf(state.search)===-1) ok=false;
      r.style.display = ok ? '' : 'none'; if(ok) visible++;
    });
    document.getElementById('norows').classList.toggle('hidden', visible>0);
  }
  document.getElementById('search').addEventListener('input', function(e){ state.search=e.target.value.toLowerCase(); apply(); });
  document.querySelectorAll('#status-filters .chip').forEach(function(c){
    c.addEventListener('click', function(){ var k=c.getAttribute('data-filter'); state.status[k]=!state.status[k]; c.classList.toggle('on', state.status[k]); apply(); });
  });
  document.querySelectorAll('.tab').forEach(function(t){
    t.addEventListener('click', function(){ document.querySelectorAll('.tab').forEach(function(x){x.classList.remove('on');}); t.classList.add('on'); state.tab=t.getAttribute('data-tab'); apply(); });
  });

  // ---- Password masking (default: masked) ----
  var MASK = String.fromCharCode(8226).repeat(8);
  function setPw(code, reveal){
    code.textContent = reveal ? code.getAttribute('data-pw') : MASK;
    code.setAttribute('data-revealed', reveal ? '1' : '0');
  }
  document.querySelectorAll('code.pw').forEach(function(c){ setPw(c, false); });
  // Per-row show/hide
  document.querySelectorAll('button.rowpw').forEach(function(b){
    b.addEventListener('click', function(){
      var code = b.parentElement.querySelector('code.pw');
      var rev = code.getAttribute('data-revealed') === '1';
      setPw(code, !rev);
      b.textContent = rev ? 'show' : 'hide';
      b.classList.toggle('on', !rev);
    });
  });
  // Show all / Hide all (button next to the PW header)
  var allShown = false;
  document.querySelectorAll('.pwbtn:not(.rowpw)').forEach(function(ab){
    ab.addEventListener('click', function(){
      allShown = !allShown;
      document.querySelectorAll('code.pw').forEach(function(c){ setPw(c, allShown); });
      document.querySelectorAll('button.rowpw').forEach(function(b){ b.textContent = allShown ? 'hide' : 'show'; b.classList.toggle('on', allShown); });
      document.querySelectorAll('.pwbtn:not(.rowpw)').forEach(function(x){ x.textContent = allShown ? 'Hide all' : 'Show all'; x.classList.toggle('on', allShown); });
    });
  });

  apply();
</script>
</body>
</html>
"@

    return $html
}
