# TalentDex

TalentDex is a World of Warcraft Retail 12.1 addon.

## Install from a release ZIP

Extract `TalentDex-0.1.0.zip` directly into your Retail `Interface/AddOns` folder. The result must be:

```
World of Warcraft/_retail_/Interface/AddOns/TalentDex/TalentDex.toc
```

The release ZIP contains one top-level folder, `TalentDex`, so no renaming or extra nesting is required.

## Package a release ZIP

Run this from the repository root in PowerShell:

```powershell
.\scripts\Package-Addon.ps1
```

It creates `dist/TalentDex-0.1.0.zip`. Upload that file as the GitHub Release asset; do not use GitHub's automatically generated **Source code (zip)** archive as the install ZIP, because GitHub adds an extra repository directory around it.
