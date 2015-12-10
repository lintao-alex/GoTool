#--------------------------------------����--------------------------------------
#ƥ��svn log�еĸĶ�·�����
New-Variable CHANGE_P -Value "�ı��·��" -Option ReadOnly -Force
#ƥ��svn log�еķָ���
New-Variable DEPART_P -Value "-{2}" -Option ReadOnly -Force
#����flaʧ��ʱ����¼�ĸ���ǰ�汾�ŵ��ļ�
New-Variable FLA_COMMITTED_FILE_NAME -Value "flaCommitted.revision" -Option ReadOnly -Force

$TOOLS_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition
cd $TOOLS_DIR
./toolCfg.ps1


#--------------------------------------����--------------------------------------
Function error($msg){
	Write-Host -ForegroundColor Red $msg
	Read-Host "��Enter�˳�"
	Exit
}

Function runScript($fullPath){

	$apartIndex = $fullPath.LastIndexOf('\')
	$prePath = $fullPath.Substring(0, $apartIndex)
	$script = $fullPath.Substring($apartIndex+1)
	cd $prePath
	& .\$script
	
	#Start-Process -FilePath $fullPath
}

Function sliceStr($org, $starI, $endI){
	$endStr = $org.Substring($endI)
	$midStr = $org.Substring($starI)
	return $midStr.SubString(0,$midStr.Length-$endStr.Length)
}

#�ռ���Ӱ����ļ�Ŀ¼
Function collectFiles($log){
	$len = $log.Count
	#���һ���Ǳ���Ŀ¼�����ݣ�Ҫ�ų�
	for($endI=$len-2; $endI -ge 0; $endI--){
		$content = $log[$endI]
		if($content -match $DEPART_P){
			break
		}
	}
	
	$FLA_PATH_P = '/fla/'
	$PIC_PATH_P = '/_ͼƬ��Դ/'
	$result = @{}
	$couldCollect = $False
	for($i=1; $i -lt $endI; $i++){
		$content = $log[$i]
		if($content -match $DEPART_P){
			$couldCollect = $False
		}elseif($content -match $CHANGE_P){
			$couldCollect = $True
		}elseif($couldCollect -and ($content -match '.png')){
			$content = $content.Trim()
			if($content.Chars(0) -ne "D"){#ɾ����ͼ���ù�
				$sIndex = $content.IndexOf($FLA_PATH_P)+1
				$eIndex = $content.IndexOf($PIC_PATH_P)
				if(($sIndex -ge 0) -and ($eIndex -gt $sIndex)){
					$content = sliceStr $content $sIndex $eIndex
					$result[$content] = 1
				}
			}
		}
	}
	return $result
}

#��ȡ��ǰ���ذ汾��
Function getCRV($path){
	$REVISION_P = "r(?<r>\d+)"
	$fLog = svn log $path -r committed
	for($i=$fLog.Count-2; $i -ge 1; $i--){
		$fContent = $fLog[$i]
		if($fContent -match $REVISION_P){
			return $Matches.r
		}
	}
	return "committed"
}

Function checkPublish(){
	Write-Host '��û��Ҫ�ύ�Ĵ����ˣ��Ƿ�Ҫ���з��汾���ߣ���y/n)' -ForegroundColor Yellow
	$input = Read-Host
	if($input.ToLower() -eq 'y'){
		runScript $PublishToolFile
	}
	Read-Host "��Enter����"
}

#--------------------------------------�߻���--------------------------------------
#�������Ŀ¼

$strIndex = $XlsxFile.LastIndexOf('\')
$xlsxPath = $XlsxFile.Substring(0, $strIndex)
svn revert --depth=infinity $xlsxPath
svn update $xlsxPath

.\copyXl.exe $XlsxFile $LangFile $SheetName $RowLenCfg
runScript $CfgToolFile

#--------------------------------------����ͼƬ--------------------------------------
#ȷ��·����ʽ
if(-not $ProjectPath.EndsWith('\')) {
	$ProjectPath += '\'
}

if(-not(Test-Path $ProjectPath)){
	$msg = "��Ŀ·�������ڣ�"+$ProjectPath
	error $msg
}

#��¼���ϴθ���ʧ��ǰ���ύ�汾�ŵ��ļ�ȫ·����
$keepFileName = $TOOLS_DIR+'\'+$FLA_COMMITTED_FILE_NAME
if(Test-Path $keepFileName){
	$flaCommittedR = Get-Content $keepFileName -Encoding UTF8
}else{
	$flaCommittedR = "committed"
}

$uiPath = $ProjectPath+'fla\ui'
$log = svn log $uiPath -v -q -r head:$flaCommittedR
$list = collectFiles $log

#test
$list = @{}
$list['fla\ui\drama\yiling'] =1
$list['fla\ui\activity\backPrize'] =1

#ȷ�������и���
if($list.Keys.Count -gt 0){
	if(-not(Test-Path $FlashPath)){
		$msg = "Flash.exe·������"+$FlashPath
		error $msg
	}
	if(-not(Test-Path $JsflPath)){
		$msg = "jsfl·������"+$JsflPath
		error $msg
	}
	
	#�������ذ汾�ţ�Ԥ������ʧ��
	$keepCrv = getCRV $uiPath
	Set-Content $keepFileName $keepCrv -Encoding UTF8
	#����svn
	svn update $uiPath
	
	$strIndex = $FlashPath.LastIndexOf('\')
	$flashPre = $FlashPath.Substring(0,$strIndex)
	$flash = $FlashPath.Substring($strIndex+1)
	$strIndex = $JsflPath.LastIndexOf('\')
	$jsflPre = $JsflPath.Substring(0, $strIndex)
	$jsfl = $JsflPath.Substring($strIndex+1)
	
	Write-Host '���ڻ�û�ҵ������jsfl�ű�ͬ��ִ�еķ�����ֻ���ֶ�ȷ��jsfl�������' -ForegroundColor Yellow
	cd $TOOLS_DIR
	$progressIndex = 0
	ForEach($filePath in $list.Keys){
		$filePathAbs = $ProjectPath+$filePath.Replace('/','\')+'\*'
		$flaFile = Get-ChildItem $filePathAbs -Include *.fla
		if($flaFile -is [System.Array]){#Ӧ�ò���������fla�����о�ֻ�ܵ�һ��
			$flaFile = $flaFile[0]
		}
		Write-Host '��fla�ļ���'$flaFile.FullName -ForegroundColor Green
		cd $flashPre
		& .\$flash $flaFile.FullName
		cd $jsflPre
		& .\$jsfl -AlwaysRunJSFL
		
		$progressIndex++
		$msg = '��ǰ���� '+$progressIndex+'/'+$list.Keys.Count + ' ȷ��jsfl������Ϻ��밴Enter����'
		Read-Host $msg
	}
	$uiCommitPath = $ProjectPath+'fla\ui*'+$ProjectPath+'bin\res\ui'
	$msg = '������Դ�滻'
	TortoiseProc.exe /command:commit /path:$uiCommitPath /logmsg:$msg
	#˳�����º��ɾ��ǰ��İ汾���ļ�
	Remove-Item $keepFileName
}

checkPublish