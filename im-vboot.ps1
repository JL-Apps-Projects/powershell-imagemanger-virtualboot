$scriptpath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
cd $scriptpath
Write-Host "Checking config file"
Foreach ($i in $(Get-Content script.conf)){
    Set-Variable -Name $i.split("=")[0] -Value $i.split("=",2)[1]
}
Write-Host "Values loaded"
Write-Host "-----------------------------------------------------------"
Write-Host "Backup repo: $backupdatastore"
Write-Host "Ram: $ram"
Write-Host "CPU: $cpus"
Write-Host "Wait time: $waittime"
Write-Host "-----------------------------------------------------------"

$machinebackups = Get-ChildItem $backupdatastore -Directory
ForEach($machine in $machinebackups ) {

$backupdirectoy = $backupdatastore + $machine
cd $backupdirectoy
Write-Host "Checking directory $backupdirectoy for backup files"
$latestimage = Get-ChildItem C_VOL-*-cd.spi | Sort-Object -Descending -Property LastWriteTime | select -First 1 | Select -exp Name
if (!$latestimage) 
{
    Write-Host "No daily backups found, moving to next location" 
}else{
$latestimagepng = $latestimage.replace("spi","png")
$fullbackuppath = $backupdirectoy + "\" + $latestimage
$fullscreenshotpath = $backupdirectoy + "\" + $latestimagepng
Write-Host "attempting to boot $machine backup $latestimage"
if(Test-Path $latestimagepng )
{
    Write-Host "$machine latest backup $latestimage has already been tested"
    Write-Host "Daily location: $fullbackuppath"
    Write-Host "Screenshot location: $fullscreenshotpath"
}else{
& "C:\Program Files (x86)\StorageCraft\ImageManager\x64\virtualboot.exe" -v -b $fullbackuppath -s -n $machine -d "xsp" -t "virtualbox" --image-password $saltkey --ram $ram --cpus $cpus --screenshot-file-path $fullscreenshotpath --screenshot-wait-time $waittime --destroy-screenshot-vm --headless
if($LASTEXITCODE -eq 0)
{
    Write-Host "Virtual boot has compleeted"
    Write-Host "Screenshot location: $fullscreenshotpath"

} elseif ($LASTEXITCODE -eq 11) {
    Write-Host "Unable to boot due to bad salt key"
    Write-Host "Please verify the Salt Key is correct and try again"
} elseif ($LASTEXITCODE -eq 12) {
    Write-Host "Unable to boot due to Broken image chain"
    Write-Host "Please verfiy the image chain and try again"
}else 
{
    Write-Host "Virtual Boot experienced an error"
}
}
}
Write-Host "-----------------------------------------------------------"
}
cd $scriptpath
