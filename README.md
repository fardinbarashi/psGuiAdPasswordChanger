# psGuiAdPasswordChanger

![](https://github.com/fardinbarashi/psGuiAdPasswordChanger/blob/main/githubRepoContentDeleteIfYouWant/logo.png)
![](https://github.com/fardinbarashi/psGuiAdPasswordChanger/blob/main/githubRepoContentDeleteIfYouWant/1.jpg)
![](https://github.com/fardinbarashi/psGuiAdPasswordChanger/blob/main/githubRepoContentDeleteIfYouWant/2.jpg)

A PowerShell GUI for resetting user passwords in on‑prem **Active Directory**.
Built to run in **PowerShell 7** (recommended) and also works in **Windows PowerShell 5.1**
For best effect run this in the domaincontroller or MGMT server

---

## News
- Version 1.2 : Added options to filter user based on attributes in the tree.
- Version 1.1 : Added options if you only want to change account options 

## Folder layout

```
psGuiAdPasswordChanger\
├─ adPasswordChanger.ps1             # minimal loader
├─ modules\                          # loads WPF assemblies + ActiveDirectory
├─ functions\function\               # PS functions one per file
├─ settings\config\config.json       # settings
├─ asset\logo\                       # logo used in GUI header + HTML report / Can be changed to customize your report.
├─ asset\xaml\MainWindow.xaml        # the GUI-layout
├─ logs\                             # daily log files
└─ files\report\                     # HTML/CSV reports (default output folder)
```

All output stays inside the application folder — reports in `files\report\`
and logs in `logs\`. Nothing is written to `C:\Temp`.

---

## What it does

* **Full OU tree** The tree shows the domain's OU structure. Expanding an OU
  reveals its child OUs and the users directly in it (loaded on demand, so large domains
  stay responsive). Each OU shows the number of users in its whole subtree, computed with a
  single fast query per level. Each user shows its display name and username plus status
  tags: 
  ```
  User [Accountname] : 
   - [Disabled][Locked] 
   - [PW Expired] [PW Expire : YYYY‑MM‑DD] 
   - [Account Expired] [Account Expire : YYYY‑MM‑DD]
  ```
  
* Password Generator :
 **GPO password policy**. The effective policy is read live and shown in the GUI, the
  generator states how complex the password must be, and **Generate sample** shows a grey
  example. Every generated password is guaranteed to satisfy the policy (length + 3‑of‑4
  complexity categories when complexity is enabled). Character sets are cryptographically
  random (`RandomNumberGenerator`). **Account options:** 
  ```
  - Enable/disable, unlock
  - password never expires, must change at next logon
  ```
  
  
* **Test mode / What‑if.** `What if ( Simulate Change Password )` always simulates.
  `Change Passwords (live)` performs the real reset — but only when **Test mode** is
  unchecked; with Test mode on, a live click is safely downgraded to a simulation.
  
**Reports.** One **HTML** + one **CSV** per top‑level OU, with an optional combined
  report for all OUs. Reports are written to `files\report\` in the application folder
  (created automatically), which opens after the run.
  The HTML report has columns Name / Account / Status / State / PW, quick filter buttons
  (**Active, Inactive, Locked, PW never expires**), a search box, and Changed/Skipped tabs.
  Table **rows** use rotating colours (columns are not coloured); **hovering** a row makes
  its text bold and changes the row background.
  
* **Logging.** Everything is logged to the on‑screen log box and to a **daily log file**
  in `logs\`

---
## Configuration — `settings\config\config.json`
The file is created with defaults on first run. Key settings:

| Section | Key | Meaning |
|--------|-----|---------|
| `Domain` | `Server` | Optional DC / domain to target (blank = current domain). |
| `Domain` | `SearchBase` | The OU used as the tree root. Blank = domain root; the top level is the OUs one level below it. |
| `Domain` | `IncludeEmptyOus` | Show OUs with 0 users. |
| `Attributes` | `PersonalIdAttribute` | AD attribute holding the personal id (default `employeeID`). |
| `Attributes` | `DisplayNameAttribute` | Attribute used as the display name. |
| `Generator` | `DefaultLength`, `UseUpper/Lower/Digit/Special`, `SpecialChars`, `AvoidAmbiguous`, `SamePasswordForAll` | Generator defaults (the policy always wins on minimum length/complexity). |
| `Report` | `OutputFolder` | Where HTML/CSV reports are written. Default `files\report` — a **relative** path is resolved against the application folder; an absolute path (e.g. `D:\Reports` or a UNC share) is used as-is. Blank = `files\report`. |
| `Report` | `OpenAfterRun` | Open the output folder when a run finishes. |
| `Report` | `CombinedReportByDefault` | Tick the combined‑report box by default. |
| `Logging` | `Folder`, `RetentionDays` | Log folder and how long to keep daily logs. |
| `Ui` | `DomainLabel`, `TestModeDefault` | Header label override; default state of the Test‑mode checkbox. |
| `Demo` | `Enabled`, `AutoFallbackWhenNoAd` | Force demo data; auto‑demo when AD is unavailable. |

---

