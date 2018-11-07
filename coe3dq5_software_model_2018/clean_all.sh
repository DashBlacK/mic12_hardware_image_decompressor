for i in *.c
do
	if [ -f "`basename $i .c`" ]; 
	then 
		echo "removing `basename $i .c`" 
		rm "`basename $i .c`" >&2
	fi
done

filetypes="bak ppm sram_d0 sram_d1 sram_d2 mic12"

for type in $filetypes
do
	files=$(ls *.${type} 2>/dev/null)
	if [ ! -z "$files" ]
	then
		echo "removing all .$type files"
		rm *.$type
	fi  
done

files=$(ls *~ 2>/dev/null)
if [ ! -z "$files" ]
then
	rm *~
fi

