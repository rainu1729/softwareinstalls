### script to take db object backup

## fetch details of objects to take backup

## create backup folder if not present

## create additional folders that are required 

## export the definations in the specific folders

$selectset=@"
  set echo off;
  set pagesize 0
  set head off;
  set feedback off;
  set pause off;
  set verify off;
  set trimspool on;
  set linesize 15000;
  set termout off;
"@


function create_directory($dir) {
    if(!(Test-Path -Path $pwd\$dir)){
        New-Item -ItemType directory -Path $pwd\$dir | Out-Null
        if(Test-Path -Path $pwd\$dir) {
            write-host "folder $dir created"
            return 'Y'}
        else { return 'N'}
    }
    else
    {
      Write-Host "Folder $dir already exists"
      return 'Y'
    }
 }

function execute_in_db($sql,$db) {
write-host "INSIDE fun to execute the stmt"
write-host "the stmt: sqlplus -silent $db"
return $sql|sqlplus -silent $db
}


#####################create folder structure #############################
$setpath= Read-Host "Set path to create export backup"

if(test-path -path $setpath) {
    Set-Location -Path $setpath
    write-host "location is set to $pwd"
}
else {
     write-host 'Given path does not exist terminating script'
    Start-Sleep -Seconds 4
    exit
} 



$create_folder = Read-Host "Create the folder structure in path $pwd enter Y or N  ??"

if ($create_folder -eq 'Y') {
    write-host "creating the folders"
    $folder1='CODEBACKUP'
    $folder2='DEV'
    $folder3='SIT'
    $folder4='UAT'
    $folder5='CODETOMOVE'
    if (create_directory($folder1) -eq 'Y') {
    Set-Location -Path $pwd\$folder1
    create_directory($folder2)
    create_directory($folder3)
    create_directory($folder4)
    Set-Location -Path $pwd\..
    write-host "working location set to $pwd"
    create_directory($folder5)
    }
    

}
else {
    write-host 'terminating script'
    Start-Sleep -Seconds 4
    exit
}

#####################create folder structure END #############################

####################### Distinguish type of objects ####################

$schema=read-host "Schema Name:"

$objects=read-host "OBJECT names comma separated"

$objects=$objects.ToUpper().Split(',')

$objects1=''

foreach($obj in $objects.ToUpper().Split(',')) { $objects1=$objects1+"'"+$obj+"',"}

$objects=$objects1.Substring(0,$objects1.Length-1)

write-host "object list "$objects

$object_list=@"
set colsep '|';
select OBJECT_NAME, OBJECT_TYPE 
From all_objects where owner='$schema'
AND OBJECT_TYPE IN ('PROCEDURE','PACKAGE','PACKAGE BODY','TRIGGER','VIEW','FUNCTION','TYPE','TYPE BODY')
AND OBJECT_NAME IN ($objects)
ORDER BY OBJECT_TYPE DESC;
"@

write-host "sql stmt "$object_list

$sqlstmt=$selectset+"`n"+$object_list

write-host "formed the stmt"
$mydb="HR/hr@xe"
write-host "going to execute the stmt"
$output=execute_in_db $sqlstmt $mydb

foreach($objtypes in $output){
$objname,$objtype=$objtypes.split('|').trim()
write-host "extracting $objname of type $objtype"
}


####################### Distinguish type of objects END ####################
