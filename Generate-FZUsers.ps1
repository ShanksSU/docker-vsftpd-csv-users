# 設定桌面 ftpdata 目錄
$Desktop = [Environment]::GetFolderPath("Desktop")
$BaseDir = Join-Path $Desktop "ftpdata"

# 如果 ftpdata 不存在就建立
if (-not (Test-Path $BaseDir)) {
    New-Item -ItemType Directory -Force -Path $BaseDir | Out-Null
    Write-Host "已建立根目錄：$BaseDir"
}

# === 讀取 CSV ===
$csvRaw = Import-Csv "users.csv"

# === 將 CSV 欄位自動標準化為小寫 ===
$csv = foreach ($row in $csvRaw) {
    $obj = @{}
    foreach ($prop in $row.PSObject.Properties) {
        $lowerName = $prop.Name.ToLower()
        $obj[$lowerName] = $prop.Value
    }
    [PSCustomObject]$obj
}

# === 建立 FileZilla XML 基本骨架 ===
$xmlStr = @"
<filezilla-server-exported xmlns:fz="https://filezilla-project.org" xmlns="https://filezilla-project.org" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" fz:product_flavour="standard" fz:product_version="1.12.0">
    <groups/>
    <users>
    </users>
</filezilla-server-exported>
"@

[xml]$xml = $xmlStr

# === Namespace 供 XPath 使用 ===
$ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
$ns.AddNamespace("fz", "https://filezilla-project.org")

# 找到 users 節點
$usersNode = $xml.SelectSingleNode("//fz:users", $ns)

# === PBKDF2 密碼生成 ===
function New-FZPasswordHash($password) {
    $iterations = 100000

    $salt = New-Object byte[] 32
    (New-Object System.Security.Cryptography.RNGCryptoServiceProvider).GetBytes($salt)

    $pbkdf2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes(
        $password, $salt, $iterations,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256
    )

    $hash = $pbkdf2.GetBytes(32)

    return @{
        Hash = [Convert]::ToBase64String($hash)
        Salt = [Convert]::ToBase64String($salt)
        Iter = $iterations
    }
}

# === 為每位使用者建立設定 ===
foreach ($u in $csv) {

    if (-not $u.username -or -not $u.password) {
        Write-Warning "CSV 資料缺少 username 或 password，該列已跳過：$u"
        continue
    }

    # home 目錄 = 桌面\ftpdata\username
    $HomePath = Join-Path $BaseDir $u.username

    # 若不存在就建立
    if (-not (Test-Path $HomePath)) {
        New-Item -ItemType Directory -Force -Path $HomePath | Out-Null
        Write-Host "已建立使用者資料夾：$HomePath"
    }

    # 建立 <user>
    $user = $xml.CreateElement("user", "https://filezilla-project.org")
    $user.SetAttribute("name", $u.username)
    $user.SetAttribute("enabled", "true")
    $usersNode.AppendChild($user) | Out-Null

    # mount_point
    $mount = $xml.CreateElement("mount_point", "https://filezilla-project.org")
    $mount.SetAttribute("tvfs_path", "/")
    $mount.SetAttribute("access", "1")
    $mount.SetAttribute("native_path", "")
    $mount.SetAttribute("new_native_path", $HomePath)
    $mount.SetAttribute("recursive", "2")
    $mount.SetAttribute("flags", "0")
    $user.AppendChild($mount)

    # 建立 /public 共同資料夾
    $PublicPath = Join-Path $BaseDir "public"
    if (-not (Test-Path $PublicPath)) {
        New-Item -ItemType Directory -Force -Path $PublicPath | Out-Null
        Write-Host "已建立公共資料夾：$PublicPath"
    }

    # 掛載 shared 公共資料夾 (/public)
    $mountPub = $xml.CreateElement("mount_point", "https://filezilla-project.org")
    $mountPub.SetAttribute("tvfs_path", "/public")
    $mountPub.SetAttribute("access", "1")
    $mountPub.SetAttribute("native_path", "")
    $mountPub.SetAttribute("new_native_path", $PublicPath)
    $mountPub.SetAttribute("recursive", "2")
    $mountPub.SetAttribute("flags", "0")
    $user.AppendChild($mountPub)

    # rate limits
    $rate = $xml.CreateElement("rate_limits", "https://filezilla-project.org")
    $rate.SetAttribute("inbound", "unlimited")
    $rate.SetAttribute("outbound", "unlimited")
    $rate.SetAttribute("session_inbound", "unlimited")
    $rate.SetAttribute("session_outbound", "unlimited")
    $user.AppendChild($rate)

    $user.AppendChild($xml.CreateElement("allowed_ips", "https://filezilla-project.org"))
    $user.AppendChild($xml.CreateElement("disallowed_ips", "https://filezilla-project.org"))

    $sol = $xml.CreateElement("session_open_limits", "https://filezilla-project.org")
    $sol.SetAttribute("files", "unlimited")
    $sol.SetAttribute("directories", "unlimited")
    $user.AppendChild($sol)

    $scl = $xml.CreateElement("session_count_limit", "https://filezilla-project.org")
    $scl.InnerText = "unlimited"
    $user.AppendChild($scl)

    $desc = $xml.CreateElement("description", "https://filezilla-project.org")
    $user.AppendChild($desc)

    # password PBKDF2
    $pwd = New-FZPasswordHash $u.password

    $pwdNode = $xml.CreateElement("password", "https://filezilla-project.org")
    $pwdNode.SetAttribute("index", "1")
    $user.AppendChild($pwdNode)

    ($hashNode = $xml.CreateElement("hash", "https://filezilla-project.org")).InnerText = $pwd.Hash
    $pwdNode.AppendChild($hashNode)

    ($saltNode = $xml.CreateElement("salt", "https://filezilla-project.org")).InnerText = $pwd.Salt
    $pwdNode.AppendChild($saltNode)

    ($iterNode = $xml.CreateElement("iterations", "https://filezilla-project.org")).InnerText = $pwd.Iter
    $pwdNode.AppendChild($iterNode)

    $methods = $xml.CreateElement("methods", "https://filezilla-project.org")
    $methods.InnerText = "password"
    $user.AppendChild($methods)
}

# === 以 UTF8 無 BOM 格式輸出 XML ===
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText("filezilla_users.xml", $xml.OuterXml, $utf8NoBom)

Write-Host "`nfilezilla_users.xml 已生成，可直接匯入 FileZilla Server" -ForegroundColor Green

