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
    param (
        [string]$Input
    )

    ($Input -split '-') |
        Where-Object { $_ -ne '' } |
        ForEach-Object { $_.Substring(0,1).ToUpper() + $_.Substring(1) } |
        Join-String
}

function To-Words {
    param (
        [string]$Input
    )

    if ([string]::IsNullOrEmpty($Input)) {
        return ""
    }

    $output = $Input `
        -replace '([A-Z]+)([A-Z][a-z])', '$1 $2' `
        -replace '([a-z0-9])([A-Z])', '$1 $2'

    return $output
}

function Replace-InFiles {
    param (
        [string]$Search,
        [string]$Replace
    )

    $self = $MyInvocation.MyCommand.Path

    Get-ChildItem -Recurse -File |
        Where-Object { $_.FullName -ne $self -and $_.FullName -notmatch '\\.git\\' } |
        ForEach-Object {
            if (Select-String -Path $_.FullName -Pattern $Search -Quiet) {
                (Get-Content $_.FullName) -replace [regex]::Escape($Search), $Replace |
                    Set-Content $_.FullName
            }
        }
}

function Rename-Files {
    param (
        [string]$Search,
        [string]$Replace
    )

    Get-ChildItem -Recurse -File |
        Where-Object { $_.Name -like "*$Search*" } |
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
# Replace placeholders
# =========================

Replace-InFiles "__DOMAIN__"    $DOMAIN
Replace-InFiles "__COMPANY__"   $COMPANY
Replace-InFiles "__PACKAGE__"   $PACKAGE
Replace-InFiles "__NAMESPACE__" $NAMESPACE
Replace-InFiles "__NAME__"      $NAME

# =========================
# Rename files
# =========================

Rename-Files "__DOMAIN__"    $DOMAIN
Rename-Files "__COMPANY__"   $COMPANY
Rename-Files "__PACKAGE__"   $PACKAGE
Rename-Files "__NAMESPACE__" $NAMESPACE
Rename-Files "__NAME__"      $NAME

# =========================
# Create Unity project
# =========================

$UNITY_HUB_PATH = Join-Path $HOME "Unity/Hub/Editor"

$UNITY_EDITOR_DIR = Get-ChildItem $UNITY_HUB_PATH -Directory |
    Where-Object { $_.Name -like "6000*" } |
    Sort-Object Name |
    Select-Object -First 1

if (-not $UNITY_EDITOR_DIR) {
    Write-Error "No Unity 6000.x editor found."
    exit 1
}

$UNITY_PATH = Join-Path $UNITY_EDITOR_DIR.FullName "Editor/Unity"
$PROJECT_PATH = Join-Path (Get-Location) "..\$NAMESPACE.TestProject"

& $UNITY_PATH `
    -createProject $PROJECT_PATH `
    -batchmode `
    -quit `
    -logFile "-"

# =========================
# Configure manifest.json
# =========================

$PACKAGE_NAME = "$DOMAIN.$COMPANY.$PACKAGE"
$PACKAGE_PATH = "file:../../unity-package-template"
$MANIFEST     = Join-Path $PROJECT_PATH "Packages/manifest.json"

if (-not (Test-Path $MANIFEST)) {
    Write-Error "manifest.json not found in $PROJECT_PATH\Packages"
    exit 1
}

$json = Get-Content $MANIFEST | ConvertFrom-Json
$json.dependencies | Add-Member -MemberType NoteProperty -Name $PACKAGE_NAME -Value $PACKAGE_PATH -Force
$json | ConvertTo-Json -Depth 10 | Set-Content $MANIFEST

# =========================
# Register project in Unity Hub
# =========================

if (Get-Command unityhub -ErrorAction SilentlyContinue) {
    unityhub -- --headless projects add --path $PROJECT_PATH
} else {
    Write-Warning "unityhub not found; project will not be added to Unity Hub."
}

# =========================
# Open project
# =========================

& $UNITY_PATH -projectPath $PROJECT_PATH

Write-Host "Init done, remember to configure precisely the package.json before starting your development"
