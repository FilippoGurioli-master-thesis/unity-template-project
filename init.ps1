#requires -Version 7.0

# =========================
# Helper functions
# =========================

function Ask-WithDefault {
    param (
        [string]$Prompt,
        [string]$Default
    )

    $input = Read-Host "$Prompt [default: $Default]"
    if (![string]::IsNullOrWhiteSpace($input)) {
        return $input
    }
    return $Default
}

function Ask-NonNull {
    param (
        [string]$Prompt
    )

    while ($true) {
        $input = Read-Host "$Prompt"
        if (![string]::IsNullOrWhiteSpace($input)) {
            return $input
        }
        Write-Warning "Value cannot be empty. Please try again."
    }
}

function Kebab-ToPascal {
    param ([string]$Input)

    ($Input -split '-') |
        Where-Object { $_ -ne '' } |
        ForEach-Object {
            $_.Substring(0,1).ToUpper() + $_.Substring(1)
        } |
        Join-String
}

function To-Words {
    param ([string]$Input)

    if ([string]::IsNullOrEmpty($Input)) {
        return ""
    }

    return $Input `
        -replace '([A-Z]+)([A-Z][a-z])', '$1 $2' `
        -replace '([a-z0-9])([A-Z])', '$1 $2'
}

# =========================
# Path pruning helpers
# =========================

$PrunedPaths = @(
    "TemplateProject/Library",
    "TemplateProject/Logs",
    "TemplateProject/Temp",
    "TemplateProject/obj",
    ".git",
    "init.ps1",
    "init.sh"
)

function Is-PrunedPath {
    param ([string]$Path)

    foreach ($p in $PrunedPaths) {
        if ($Path -match [regex]::Escape($p)) {
            return $true
        }
    }
    return $false
}

# =========================
# Replace placeholders
# =========================

function Replace-InFiles {
    param (
        [string]$Search,
        [string]$Replace
    )

    $self = $MyInvocation.MyCommand.Path

    Get-ChildItem -Recurse -File |
        Where-Object {
            $_.FullName -ne $self -and -not (Is-PrunedPath $_.FullName)
        } |
        ForEach-Object {
            if (Select-String -Path $_.FullName -Pattern $Search -Quiet) {
                (Get-Content $_.FullName) `
                    -replace [regex]::Escape($Search), $Replace |
                    Set-Content $_.FullName
            }
        }
}

# =========================
# Rename directories
# =========================

function Rename-Dirs {
    param (
        [string]$Search,
        [string]$Replace
    )

    Get-ChildItem -Recurse -Directory |
        Sort-Object FullName -Descending | # depth-first
        Where-Object {
            $_.Name -like "*$Search*" -and -not (Is-PrunedPath $_.FullName)
        } |
        ForEach-Object {
            $newPath = $_.FullName -replace [regex]::Escape($Search), $Replace
            Rename-Item $_.FullName $newPath
        }
}

# =========================
# Rename files
# =========================

function Rename-Files {
    param (
        [string]$Search,
        [string]$Replace
    )

    Get-ChildItem -Recurse -File |
        Where-Object {
            $_.Name -like "*$Search*" -and -not (Is-PrunedPath $_.FullName)
        } |
        ForEach-Object {
            $newName = $_.Name -replace [regex]::Escape($Search), $Replace
            Rename-Item $_.FullName $newName -ErrorAction SilentlyContinue
        }
}

# =========================
# Read customer values
# =========================

$DOMAIN    = Ask-WithDefault "Enter the top level domain" "com"
$COMPANY   = Ask-NonNull "Enter your company name (e.g. 'mycompany')"
$PACKAGE   = Ask-NonNull "Enter your package name (e.g. 'awesome-tool')"
$NAMESPACE = Ask-WithDefault "Enter the default namespace" (Kebab-ToPascal $PACKAGE)
$NAME      = To-Words $NAMESPACE

Write-Host "The resulting package unique ID is $DOMAIN.$COMPANY.$PACKAGE"
Write-Host "The namespace is $NAMESPACE"
Write-Host "The package display name is $NAME"

# =========================
# Rename directories
# =========================

Rename-Dirs "__DOMAIN__"    $DOMAIN
Rename-Dirs "__COMPANY__"   $COMPANY
Rename-Dirs "__PACKAGE__"   $PACKAGE
Rename-Dirs "__NAMESPACE__" $NAMESPACE
Rename-Dirs "__NAME__"      $NAME

# =========================
# Rename files
# =========================

Rename-Files "__DOMAIN__"    $DOMAIN
Rename-Files "__COMPANY__"   $COMPANY
Rename-Files "__PACKAGE__"   $PACKAGE
Rename-Files "__NAMESPACE__" $NAMESPACE
Rename-Files "__NAME__"      $NAME

# =========================
# Replace placeholders
# =========================

Replace-InFiles "__DOMAIN__"    $DOMAIN
Replace-InFiles "__COMPANY__"   $COMPANY
Replace-InFiles "__PACKAGE__"   $PACKAGE
Replace-InFiles "__NAMESPACE__" $NAMESPACE
Replace-InFiles "__NAME__"      $NAME

# =========================
# Locate Unity editor
# =========================

$UnityEditorsRoot = Join-Path $HOME "Unity/Hub/Editor"

$UnityEditorDir = Get-ChildItem $UnityEditorsRoot -Directory |
    Where-Object { $_.Name -like "6000*" } |
    Sort-Object Name |
    Select-Object -First 1

if (-not $UnityEditorDir) {
    Write-Error "No Unity 6000.x editor found."
    exit 1
}

$UNITY_PATH   = Join-Path $UnityEditorDir.FullName "Editor/Unity"
$PROJECT_PATH = "./TemplateProject"

# =========================
# Open Unity project
# =========================

& $UNITY_PATH -projectPath $PROJECT_PATH

Write-Host "Init done, remember to configure precisely the package.json before starting your development"
