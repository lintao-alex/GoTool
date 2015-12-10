// main.go
package main

import (
	"./xlsx"
	"flag"
	"fmt"
	"io/ioutil"
	"strconv"
)

func main() {
	//	filePath := "E:\\game\\configParse\\haiWai\\haiwai_qianduan.xlsx"
	//	outPath := "E:\\game\\hanguo\\bin\\res\\lang\\lang.txt"
	//	sheetName := "代码中的字"
	//	rowLenCfg := 0
	flag.Parse()
	var xlsxFilePath string = flag.Arg(0)
	var langFilePath string = flag.Arg(1)
	var sheetName string = flag.Arg(2)
	var rowLenCfg int
	if len(flag.Args()) >= 4 {
		tranceV, intErr := strconv.Atoi(flag.Arg(3))
		if intErr != nil {
			fmt.Println("指定的列数有问题")
			return
		} else {
			rowLenCfg = tranceV
		}
	} else {
		rowLenCfg = 0
	}
	xlsxFile, err := xlsx.OpenFile(xlsxFilePath)
	if err != nil {
		fmt.Println("文件不存在，path:", xlsxFilePath)
		return
	}
	content := ""
	page := xlsxFile.Sheet[sheetName]
	rows := page.Rows
	appendRow(rows[0].Cells, rowLenCfg, &content)
	rowSize := page.MaxRow
	for i := 1; i < rowSize; i++ {
		content += "\n"
		appendRow(rows[i].Cells, rowLenCfg, &content)
	}
	err = ioutil.WriteFile(langFilePath, []byte(content), 0644)
	if err != nil {
		fmt.Println("文件写入失败，path:", langFilePath)
	} else {
		fmt.Println("文件写入成功")
	}

}

func appendRow(cells []*xlsx.Cell, rLen int, content *string) {
	cell := cells[0]
	*content += cell.Value
	if rLen <= 0 {
		rLen = len(cells)
	}

	for i := 1; i < rLen; i++ {
		cell = cells[i]
		*content += "\t" + cell.Value
	}
}
