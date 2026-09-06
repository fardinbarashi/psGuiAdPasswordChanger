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
=======

---


## Folder layout

```
psGuiAdPasswordChanger\
├─ adPasswordChanger 1.1.ps1         # minimal loader
├─ modules\                          # loads WPF assemblies + ActiveDirectory
├─ functions\function\               # functions, one psfile per function
├─ settings\config\config.json       # settings
├─ asset\logo\                       # logo used in GUI header + HTML report / Can be changed to customize your report.
├─ asset\xaml\MainWindow.xaml        # the GUI-layout
├─ logs\                             # log files
└─ files\report\                     # HTML/CSV reports
```
---

## Features
### OU tree
  **Full OU tree** 
  The tree shows the domain's OU structure. 
  Expanding an OU reveals its child OUs and the users directly in it.
  Each OU shows the number of users in its whole subtree, 
  Each user shows its display name and username plus status
  Status Tags: 
  | Tag | Meaning |
  |-----|---------|
  | `User [Accountname]` | The account the tags below apply to |
  | `[Disabled]` | The account is disabled |
  | `[Locked]` | The account is locked out |
  | `[PW Expired]` | The password has already expired |
  | `[PW Expire : YYYY-MM-DD]` | Date the password expires |
  | `[Account Expired]` | The account has already expired |
  | `[Account Expire : YYYY-MM-DD]` | Date the account expires |
  
  
### Password Generator :
  **GPO password policy**. 
  The effective policy is read live and shown in the GUI, the
  generator states how complex the password must be, and **Generate sample** shows a grey
  example. Every generated password is will satisfy the policy (length + 3‑of‑4
  complexity categories when complexity is enabled). 
  Character sets are cryptographically random (`RandomNumberGenerator`). 
  
### Account options:
| Option | Description |
|--------|-------------|
| Enable / disable | Enable or disable the account |
| Unlock | Unlock a locked-out account |
| Password never expires | Set the password so it never expires |
| Must change at next logon | Require a password change at the next sign-in |
  
  
### Test mode / What‑if.
  `What if ( Simulate Change Password )` always simulates.
  `Change Passwords (live)` performs the real process — but only when **Test mode** is
   unchecked; with Test mode on, a live click is downgraded to a simulation.
  
### Reports.
   One HTML + one CSV per top‑level OU, with an optional combined report for all OUs. 
   Reports are written to `files\report\` in the application folder
   The HTML report has columns Name / Account / State / Options / PW, quick filter buttons: **Active, Inactive, Locked, PW never expires**, 
   a search box, and Changed/Skipped tabs.
  
---

## Configuration — config.json 
The file settings\config\config.json is created with defaults on first run. 
### Key settings:
| Section | Key | Meaning |
|--------|-----|---------|
| `Domain` | `Server` | Optional DC / domain to target (blank = current domain). |
| `Domain` | `SearchBase` | The OU used as the tree root. Blank = domain root; the top level is the OUs one level below it. |
| `Domain` | `IncludeEmptyOus` | Show OUs with 0 users. |
| `Attributes` | `DisplayNameAttribute` | Attribute used as the display name. |
| `Generator` | `DefaultLength`, `UseUpper/Lower/Digit/Special`, `SpecialChars`, `AvoidAmbiguous`, `SamePasswordForAll` | Generator defaults (the policy always wins on minimum length/complexity). |
| `Report` | `OutputFolder` | Where HTML/CSV reports are written. Default `files\report` — a **relative** path is resolved against the application folder; an absolute path (e.g. `D:\Reports` or a UNC share) is used as-is. Blank = `files\report`. |
| `Report` | `OpenAfterRun` | Open the output folder when a run finishes. |
| `Report` | `CombinedReportByDefault` | Tick the combined‑report box by default. |
| `Logging` | `Folder`, `RetentionDays` | Log folder and how long to keep daily logs. |
| `Ui` | `DomainLabel`, `TestModeDefault` | Header label override; default state of the Test‑mode checkbox. |
| `Demo` | `Enabled`, `AutoFallbackWhenNoAd` | Force demo data; auto‑demo when AD is unavailable. |

---

