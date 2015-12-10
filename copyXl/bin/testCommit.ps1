$PublishToolFile = "E:\tools\发版本工具_win\publish.ps1"


Function runScript($fullPath){
	$apartIndex = $fullPath.LastIndexOf('\')
	$prePath = $fullPath.Substring(0, $apartIndex)
	$script = $fullPath.Substring($apartIndex+1)
	cd $prePath
	& .\$script
}

runScript $PublishToolFile