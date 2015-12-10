#--------------------------------------常量--------------------------------------
#匹配svn log中的改动路径标记
New-Variable CHANGE_P -Value "改变的路径" -Option ReadOnly -Force
#匹配svn log中的分隔符
New-Variable DEPART_P -Value "-{2}" -Option ReadOnly -Force
#更新fla失败时，记录的更新前版本号的文件
New-Variable FLA_COMMITTED_FILE_NAME -Value "flaCommitted.revision" -Option ReadOnly -Force

$TOOLS_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition
cd $TOOLS_DIR
./toolCfg.ps1


#--------------------------------------方法--------------------------------------
Function error($msg){
	Write-Host -ForegroundColor Red $msg
	Read-Host "按Enter退出"
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

#收集受影响的文件目录
Function collectFiles($log){
	$len = $log.Count
	#最后一个是本地目录的内容，要排除
	for($endI=$len-2; $endI -ge 0; $endI--){
		$content = $log[$endI]
		if($content -match $DEPART_P){
			break
		}
	}
	
	$FLA_PATH_P = '/fla/'
	$PIC_PATH_P = '/_图片资源/'
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
			if($content.Chars(0) -ne "D"){#删掉的图不用管
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

#获取当前本地版本号
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
	Write-Host '若没有要提交的代码了，是否要运行发版本工具？（y/n)' -ForegroundColor Yellow
	$input = Read-Host
	if($input.ToLower() -eq 'y'){
		runScript $PublishToolFile
	}
	Read-Host "按Enter结束"
}

#--------------------------------------策划表--------------------------------------
#表格所在目录

$strIndex = $XlsxFile.LastIndexOf('\')
$xlsxPath = $XlsxFile.Substring(0, $strIndex)
svn revert --depth=infinity $xlsxPath
svn update $xlsxPath

.\copyXl.exe $XlsxFile $LangFile $SheetName $RowLenCfg
runScript $CfgToolFile

#--------------------------------------美术图片--------------------------------------
#确保路径格式
if(-not $ProjectPath.EndsWith('\')) {
	$ProjectPath += '\'
}

if(-not(Test-Path $ProjectPath)){
	$msg = "项目路径不存在："+$ProjectPath
	error $msg
}

#记录着上次更新失败前的提交版本号的文件全路径名
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

#确保美术有更新
if($list.Keys.Count -gt 0){
	if(-not(Test-Path $FlashPath)){
		$msg = "Flash.exe路径错误："+$FlashPath
		error $msg
	}
	if(-not(Test-Path $JsflPath)){
		$msg = "jsfl路径错误："+$JsflPath
		error $msg
	}
	
	#保留本地版本号，预防更新失败
	$keepCrv = getCRV $uiPath
	Set-Content $keepFileName $keepCrv -Encoding UTF8
	#更新svn
	svn update $uiPath
	
	$strIndex = $FlashPath.LastIndexOf('\')
	$flashPre = $FlashPath.Substring(0,$strIndex)
	$flash = $FlashPath.Substring($strIndex+1)
	$strIndex = $JsflPath.LastIndexOf('\')
	$jsflPre = $JsflPath.Substring(0, $strIndex)
	$jsfl = $JsflPath.Substring($strIndex+1)
	
	Write-Host '由于还没找到如何让jsfl脚本同步执行的方法，只好手动确认jsfl运行完毕' -ForegroundColor Yellow
	cd $TOOLS_DIR
	$progressIndex = 0
	ForEach($filePath in $list.Keys){
		$filePathAbs = $ProjectPath+$filePath.Replace('/','\')+'\*'
		$flaFile = Get-ChildItem $filePathAbs -Include *.fla
		if($flaFile -is [System.Array]){#应该不会有两个fla，真有就只管第一个
			$flaFile = $flaFile[0]
		}
		Write-Host '打开fla文件：'$flaFile.FullName -ForegroundColor Green
		cd $flashPre
		& .\$flash $flaFile.FullName
		cd $jsflPre
		& .\$jsfl -AlwaysRunJSFL
		
		$progressIndex++
		$msg = '当前进度 '+$progressIndex+'/'+$list.Keys.Count + ' 确认jsfl运行完毕后，请按Enter继续'
		Read-Host $msg
	}
	$uiCommitPath = $ProjectPath+'fla\ui*'+$ProjectPath+'bin\res\ui'
	$msg = '美术资源替换'
	TortoiseProc.exe /command:commit /path:$uiCommitPath /logmsg:$msg
	#顺利更新后就删除前面的版本号文件
	Remove-Item $keepFileName
}

checkPublish