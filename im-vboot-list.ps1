$scriptpath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
cd $scriptpath
$backupsalt = import-csv "key.conf"
Write-Host "Checking config file"
Foreach ($clientfolder in $backupsalt) {
    $backupdatastore = $clientfolder.path
    $saltkey = $clientfolder.salt
    $clientname = $clientfolder.client
    Foreach ($i in $(Get-Content script.conf)) {
        Set-Variable -Name $i.split("=")[0] -Value $i.split("=", 2)[1]
    }
    Write-Host "Values loaded"
    Write-Host "-----------------------------------------------------------"
    Write-Host "Backup repo: $backupdatastore"
    Write-Host "Ram: $ram"
    Write-Host "CPU: $cpus"
    Write-Host "Wait time: $waittime"
    Write-Host "-----------------------------------------------------------"

    $machinebackups = Get-ChildItem $backupdatastore -Directory
    ForEach ($machine in $machinebackups ) {
        #$clientname = $backupdatastore.Split("\")
        #$saltkey = $backupsalt | Where client -eq $clientname[4] | Select -exp salt
        $backupdirectoy = $backupdatastore + $machine
        cd $backupdirectoy
        Write-Host "Moving to $backupdirectoy"
        Write-Host "Checking directory $backupdirectoy for backup files"
        $latestimage = Get-ChildItem C_VOL-*-cd.spi | Sort-Object -Descending -Property LastWriteTime | select -First 1 | Select -exp Name
        if (!$latestimage) {
            Write-Host "No daily backups found, moving to next location" 
        }
        else {
            $latestimagepng = $latestimage.replace("spi", "png")
            $fullbackuppath = $backupdirectoy + "\" + $latestimage
            $fullscreenshotpath = $backupdirectoy + "\" + $latestimagepng
            Write-Host "attempting to boot $machine backup $latestimage"
            if (Test-Path $latestimagepng ) {
                Write-Host "$machine latest backup $latestimage has already been tested"
                Write-Host "Daily location: $fullbackuppath"
                Write-Host "Screenshot location: $fullscreenshotpath"
            }
            else {
                & "C:\Program Files (x86)\StorageCraft\ImageManager\x64\virtualboot.exe" -v -b $fullbackuppath -s -n $machine -d "xsp" -t "virtualbox" --image-password $saltkey --ram $ram --cpus $cpus --screenshot-file-path $fullscreenshotpath --screenshot-wait-time $waittime --destroy-screenshot-vm --headless
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Virtual boot has completed"
                    Write-Host "Screenshot location: $fullscreenshotpath"
                    $imageencode = [convert]::ToBase64String((Get-Content $fullscreenshotpath -Encoding byte))
                    $body = '{
"@type": "MessageCard",
"@context": "http://schema.org/extensions",
"themeColor": "0076D7",
"summary": "Virtual boot has completed - ' + $machine + '",
"sections": [{
    "activityTitle": "![TestImage](data:image/png;base64,' + $imageencode + ')Virtual boot has completed - ' + $machine + '",
    "activitySubtitle": "Screenshot location: ' + $fullscreenshotpath + '",
    "activityImage": "data:image/png;base64,' + $imageencode + '",
    "facts": [{
        "name": "Client:",
        "value": "' + $clientname + '"
    }, {
        "name": "Machine:",
        "value": "' + $machine + '"
    }, {
        "name": "Daily File:",
        "value": "' + $latestimage + '"
    }],
    "markdown": true
}]
}'

                    Invoke-RestMethod -Method post -ContentType 'Application/Json' -Body $body -Uri $webhookurl

                }
                elseif ($LASTEXITCODE -eq 11) {
                    Write-Host "Unable to boot due to bad salt key"
                    Write-Host "Please verify the Salt Key is correct and try again"

                    $body = ConvertTo-Json -Depth 2 @{
                        text = $fullbackuppath + "<br>" + 'Unable to boot due to bad salt key' + "<br>" + 'Please verify the Salt Key is correct and try again'
                    }

                    Invoke-RestMethod -Method post -ContentType 'Application/Json' -Body $body -Uri $webhookurl
                }
                elseif ($LASTEXITCODE -eq 12) {
                    Write-Host "Unable to boot due to Broken image chain"
                    Write-Host "Please verfiy the image chain and try again"

                    $body = ConvertTo-Json -Depth 2 @{
                        text = $fullbackuppath + "<br>" + 'Unable to boot due to Broken image chain' + "<br>" + 'Please verfiy the image chain and try again'
                    }

                    Invoke-RestMethod -Method post -ContentType 'Application/Json' -Body $body -Uri $webhookurl
                }
                else {
                    Write-Host "Virtual Boot experienced an error"
                    $body = ConvertTo-Json -Depth 2 @{
                        text = $fullbackuppath + "<br>" + 'Virtual Boot experienced an error'
                    }

                    Invoke-RestMethod -Method post -ContentType 'Application/Json' -Body $body -Uri $webhookurl
                }
            }
        }
        Write-Host "-----------------------------------------------------------"
    }
    cd $scriptpath
}
