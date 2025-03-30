# Input bindings are passed in via param block.
param($Timer)

# Variables
$TenantId = "自分TenantId"
$ClientId = "自分ClientId"
$ClientSecret = "自分ClientSecret"
$RefreshTokenFilePath = "refresh_token.txt"#実際にバスに書き
$FileToCheck = "aws環境構築.xlsx"#実際にバスに書き
$AzureDevOpsToken = "OjJaRnhBcTVXR3FCZ3pMVDQzSVRpbUk3SXBjckprQ2hRODRPNzd5bjlyVktZbXBFU3U4YUxKUVFKOTlBTEFDQUFBQUFyc3phaUFBQVNBWkRPR2I2Yw=="#azureDevopsのPATを取得してBase64エンコードにする
$RepoUrl = "https://dev.azure.com/xingranwang/onewonder_test/_apis/git/repositories/249d658a-10c1-48cd-b139-cf479123e9aa"#自分プロジェクトを切り替え
$TokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"#最新accessTokenを取得

# Function to log messages
Function Log {
    param (
        [string]$Message,
        [string]$Level = "Information"
    )
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$Time] [$Level] $Message"
}

# Main logic
try {
    # Step 1: Refresh Access Token
    if (Test-Path $RefreshTokenFilePath) {
        $RefreshToken = Get-Content -Path $RefreshTokenFilePath -Raw
        Log "Found existing refresh token. Attempting to get a new access token..."

        $Body = @{
            grant_type    = "refresh_token"
            client_id     = $ClientId
            client_secret = $ClientSecret
            refresh_token = $RefreshToken
        }

        $response = Invoke-RestMethod -Uri $TokenUrl -Method Post -Body $Body -ContentType "application/x-www-form-urlencoded"
        $AccessToken = $response.access_token
        $NewRefreshToken = $response.refresh_token

        # Save updated Refresh Token
        Set-Content -Path $RefreshTokenFilePath -Value $NewRefreshToken
        Log "Access Token acquired successfully using Refresh Token."
    } else {
        throw "Refresh Token file not found. Please authenticate again to generate a new refresh token."
    }

    # Step 2: Get File's Download URL from OneDrive
    $Headers = @{ Authorization = "Bearer $AccessToken" }
    $ListFilesUrl = "https://graph.microsoft.com/v1.0/me/drive/root/children"
    $Response = Invoke-RestMethod -Uri $ListFilesUrl -Headers $Headers -Method Get

    $FileItem = $Response.value | Where-Object { $_.name -eq $FileToCheck }
    if (-not $FileItem) {
        throw "File '$FileToCheck' does not exist in OneDrive."
    }

    $DownloadUrl = $FileItem."@microsoft.graph.downloadUrl"
    Log "Download URL: $DownloadUrl"

    # Step 3: Download and Process the File
    Log "Downloading file content..."
    $LocalFilePath = "temp.xlsx"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $LocalFilePath

    Log "Parsing Excel file..."
    $ExcelContent = Import-Excel -Path $LocalFilePath
    $FilteredData = $ExcelContent | Select-Object -Property 'IAMユーザー', 'ポリシー'

    # Convert to JSON and Base64
    $JsonOutput = $FilteredData | ConvertTo-Json -Depth 10
    $Base64Content = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($JsonOutput))
    Remove-Item $LocalFilePath -Force

    # Step 4: Get Latest ObjectId from Azure DevOps
    Log "Fetching latest object ID from Azure DevOps..."
    $GetUrl = "$RepoUrl/refs?api-version=6.0"
    $DevOpsHeaders = @{
        "Content-Type"  = "application/json"
        "Authorization" = "Basic $AzureDevOpsToken"
    }
    $GitResponse = Invoke-RestMethod -Uri $GetUrl -Method Get -Headers $DevOpsHeaders
    $LatestObjectId = $GitResponse.value | Where-Object { $_.name -eq "refs/heads/master" } | Select-Object -ExpandProperty objectId
    if (-not $LatestObjectId) { throw "No valid objectId found for 'refs/heads/master'." }
    Log "Latest Object ID: $LatestObjectId"

    # Step 5: Upload JSON Data to Azure DevOps
    Log "Uploading updated JSON file to Azure DevOps..."
    $PostUrl = "$RepoUrl/pushes?api-version=6.0"
    $Body = @{
        refUpdates = @(
            @{
                name        = "refs/heads/master"
                oldObjectId = $LatestObjectId
            }
        )
        commits = @(
            @{
                comment = "Updated iamusers.json file"
                changes = @(
                    @{
                        changeType = "edit"
                        item = @{
                            path = "/iamusers.json"
                        }
                        newContent = @{
                            content     = $Base64Content
                            contentType = "base64encoded"
                        }
                    }
                )
            }
        )
    } | ConvertTo-Json -Depth 10 -Compress

    $PostResponse = Invoke-RestMethod -Uri $PostUrl -Method Post -Headers $DevOpsHeaders -Body $Body
    Log "File uploaded successfully! Response: $($PostResponse | ConvertTo-Json -Depth 10)"

} catch {
    Log "An error occurred: $_" -Level "Error"
    exit 1
}

Log "PowerShell timer trigger function ran successfully!"
