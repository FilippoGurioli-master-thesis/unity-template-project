# helper functions

function Info($Message) {
  Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Warn($Message) {
  Write-Warning "[WARN] $Message"
}

function ErrorMsg($Message) {
  Write-Error "[ERRO] $Message"
}

function Ask-WithDefault($Prompt, $Default) {
  $input = Read-Host "$Prompt [default: $Default]"
  if (![string]::IsNullOrWhiteSpace($input)) {
    return $input
  }
  return $Default
}

function Ask-NonNull($Prompt) {
  while ($true) {
    $input = Read-Host "$Prompt"
    if (![string]::IsNullOrWhiteSpace($input)) {
      return $input
    }
    Write-Warning "Warning: value cannot be empty. Please try again."
  }
}

function Kebab-ToPascal($Input) {
  return ($Input -split '-') | ForEach-Object {
    if ($_ -ne '') {
      $_.Substring(0,1).ToUpper() + $_.Substring(1)
    }
  } | Join-String
}

function To-Words($Input) {
  if ([string]::IsNullOrEmpty($Input)) {
    return ""
  }

  return ($Input `
    -replace '([A-Z]+)([A-Z][a-z])', '$1 $2' `
    -replace '([a-z0-9])([A-Z])', '$1 $2')
}

function To-Lower($Input) {
  if ($Input -cmatch '[A-Z]') {
    Warn "Uppercase letters detected. Unity package IDs must be lowercase. Converting to lowercase."
  }
  return $Input.ToLowerInvariant()
}

function Replace-InFiles($Search, $Replace) {
  Get-ChildItem -Recurse -File |
    Where-Object {
      $_.FullName -notmatch '\\TemplateProject\\(Library|Logs|Temp|obj)\\' `
      -and $_.FullName -notmatch '\\.git\\' `
      -and $_.Name -notmatch '^init\.'
    } |
    ForEach-Object {
      $content = Get-Content $_.FullName -Raw
      if ($content -match [regex]::Escape($Search)) {
        $content = $content -replace [regex]::Escape($Search), $Replace
        Set-Content $_.FullName $content -Encoding UTF8
      }
    }
}

function Rename-Dirs($Search, $Replace) {
  Get-ChildItem -Recurse -Directory |
    Where-Object {
      $_.FullName -notmatch '\\TemplateProject\\(Library|Logs|Temp|obj)\\' `
      -and $_.Name -like "*$Search*"
    } |
    Sort-Object FullName -Descending |
    ForEach-Object {
      $newName = $_.Name -replace [regex]::Escape($Search), $Replace
      Rename-Item $_.FullName $newName
    }
}

function Rename-Files($Search, $Replace) {
  Get-ChildItem -Recurse -File |
    Where-Object {
      $_.FullName -notmatch '\\TemplateProject\\(Library|Logs|Temp|obj)\\' `
      -and $_.Name -like "*$Search*"
    } |
    ForEach-Object {
      $newName = $_.Name -replace [regex]::Escape($Search), $Replace
      Rename-Item $_.FullName $newName
    }
}

#---------------------------------------------------------------------------------------------------

# Read customer values
$DOMAIN     = To-Lower (Ask-WithDefault "Enter the top level domain" "com")
$COMPANY    = To-Lower (Ask-NonNull "Enter your company name (e.g. 'mycompany')")
$PACKAGE    = To-Lower (Ask-NonNull "Enter your package name (e.g. 'awesome-tool')")
$NAMESPACE  = Ask-WithDefault "Enter the default namespace" (Kebab-ToPascal $PACKAGE)
$DESCRIPTION = Ask-WithDefault "Enter a description" ""
$NAME       = To-Words $NAMESPACE
$GIT_USER   = git config user.name
$GIT_MAIL   = git config user.email

Info "The resulting package unique ID is $DOMAIN.$COMPANY.$PACKAGE"
Info "The namespace is $NAMESPACE"
Info "The package display name is $NAME"

# Rename directories
Info "Renaming dirs with __DOMAIN__=$DOMAIN"
Rename-Dirs "__DOMAIN__" $DOMAIN
Info "Renaming dirs with __COMPANY__=$COMPANY"
Rename-Dirs "__COMPANY__" $COMPANY
Info "Renaming dirs with __PACKAGE__=$PACKAGE"
Rename-Dirs "__PACKAGE__" $PACKAGE
Info "Renaming dirs with __NAMESPACE__=$NAMESPACE"
Rename-Dirs "__NAMESPACE__" $NAMESPACE
Info "Renaming dirs with __NAME__=$NAME"
Rename-Dirs "__NAME__" $NAME

# Rename files
Info "Renaming files with __DOMAIN__=$DOMAIN"
Rename-Files "__DOMAIN__" $DOMAIN
Info "Renaming files with __COMPANY__=$COMPANY"
Rename-Files "__COMPANY__" $COMPANY
Info "Renaming files with __PACKAGE__=$PACKAGE"
Rename-Files "__PACKAGE__" $PACKAGE
Info "Renaming files with __NAMESPACE__=$NAMESPACE"
Rename-Files "__NAMESPACE__" $NAMESPACE
Info "Renaming files with __NAME__=$NAME"
Rename-Files "__NAME__" $NAME

# Replace content
Replace-InFiles "__DOMAIN__" $DOMAIN
Replace-InFiles "__COMPANY__" $COMPANY
Replace-InFiles "__PACKAGE__" $PACKAGE
Replace-InFiles "__NAMESPACE__" $NAMESPACE
Replace-InFiles "__NAME__" $NAME
Replace-InFiles "__DESCRIPTION__" $DESCRIPTION
Replace-InFiles "__GIT_USER__" $GIT_USER
Replace-InFiles "__GIT_MAIL__" $GIT_MAIL

# Unity
$UnityEditor = Get-ChildItem "$HOME/Unity/Hub/Editor" -Directory -Filter "6000*" |
  Sort-Object Name |
  Select-Object -First 1 |
  ForEach-Object { Join-Path $_.FullName "Editor\Unity.exe" }

$ProjectPath = Resolve-Path "./TemplateProject"

Info "Opening Unity project"
Start-Process $UnityEditor -ArgumentList "-projectPath `"$ProjectPath`""

# Install dependencies
Info "Installing dotnet and npm dependencies"
npm i
dotnet tool restore

# Git hooks
Info "Installing git hooks"
npx lefthook install

# Cleanup
Info "Removing .template file"
Remove-Item .template -Force

Info "Removing init files since they're not needed anymore"
Remove-Item init.sh, init.ps1 -Force

Info "Waiting unity to update lock file"
Start-Sleep -Seconds 2

Info "Committing changes"
git add .
git commit -m "chore(init): initialize project from template"

Info "Init done. Remember to configure package.json precisely and add a LICENSE before publishing."
