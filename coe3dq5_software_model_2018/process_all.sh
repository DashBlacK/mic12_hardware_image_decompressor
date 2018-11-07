for i in *.c
do 
    echo "compiling `basename $i .c`" 
    gcc "$i" -lm -o "`basename $i .c`"
done

printf "\n"
echo "check if first argument is 1, in which case use Q1; in any other case use Q0"
printf "\n"
q=0;
if [[ $1 -eq 1 ]]; 
then
    q=1;
fi

for j in *.bmp
do 
	./bmp_to_ppm $j "`basename $j .bmp`_in.ppm"
    printf "\n"
	./encode_all "`basename $j .bmp`_in.ppm" "`basename $j .bmp`.mic12" $q
    printf "\n"
	./decode_m3 "`basename $j .bmp`.mic12" "`basename $j .bmp`.sram_d2"
    printf "\n"
	./decode_m2 "`basename $j .bmp`.sram_d2" "`basename $j .bmp`.sram_d1"
    printf "\n"
	./decode_m1 "`basename $j .bmp`.sram_d1" "`basename $j .bmp`.sram_d0" "`basename $j .bmp`_out.ppm"
    printf "\n"
	./compare_ppm "`basename $j .bmp`_in.ppm" "`basename $j .bmp`_out.ppm"
    printf "\n"
done
