//coded by Jason Thong for COE3DQ5 2018
//convert a *.bmp (bitmap file) to a *.ppm (portable pixel map file)

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
	int i, j, k, width, height;
	char input_filename[200], output_filename[200];
	unsigned char *r_image, *g_image, *b_image;
	FILE *file_ptr;
	
	//get input file name either from first command line argument or from the user interface (command prompt)
	if (argc<2) {
		printf("enter the input file name including the .bmp extension: ");
		gets(input_filename);
	}
	else strcpy(input_filename, argv[1]);
	
	//open input file
	file_ptr = fopen(input_filename, "rb");
	if (file_ptr==NULL) {
		printf("can't open file %s for binary reading, exiting...\n", input_filename);
		exit(1);
	}
	else printf("opened input file %s\n", input_filename);
	
	//get output file name either from second command line argument or from the user interface (command prompt)
	if (argc<3) {
		printf("enter the output file name including the .ppm extension: ");
		gets(output_filename);
	}
	else strcpy(output_filename, argv[2]);
	
	//ignore unimportant parts of bmp header
	for (i=0; i<18; i++) fgetc(file_ptr);

	//read image width and height from bmp header
	width = fgetc(file_ptr);
	for (i=8; i<=24; i+=8) width += fgetc(file_ptr) << i;
	height = fgetc(file_ptr);
	for (i=8; i<=24; i+=8) height += fgetc(file_ptr) << i;
	if (height < 0 || width < 0) {
		printf("unsupported format, please (re)save the image as .bmp in Paint within Windows\n");
		printf("as a trick to force Paint to resave the image, invert the colors twice\n");
		printf("exiting...\n");
		exit(1);
	}
	printf("image size is %d (width) by %d (height) pixels\n", width, height);
	
	//ignore unimportant parts of bmp header
	for (i=0; i<28; i++) fgetc(file_ptr);

	//buffer the entire image in memory because the output row order is different between bmp (backwards) and ppm (forwards)
	r_image = (unsigned char *)malloc(sizeof(unsigned char)*width*height);
	g_image = (unsigned char *)malloc(sizeof(unsigned char)*width*height);
	b_image = (unsigned char *)malloc(sizeof(unsigned char)*width*height);
	if (r_image==NULL || g_image==NULL || b_image==NULL) { printf("malloc failed :(\n)"); exit(1); }

	//read bmp image, when reading file sequentially, will get data for the bottom row first, go across this row, then go up a row, and so on...
	for (i=0; i<height; i++) for (j=0; j<width; j++) {	//color order is BGR
		b_image[width*(height-1-i)+j] = fgetc(file_ptr);
		g_image[width*(height-1-i)+j] = fgetc(file_ptr);
		r_image[width*(height-1-i)+j] = fgetc(file_ptr);
	}
	if (fgetc(file_ptr)!=EOF) {
		printf("unsupported format, please (re)save the image as .bmp in Paint within Windows\n");
		printf("as a trick to force Paint to resave the image, invert the colors twice\n");
		printf("exiting...\n");
		exit(1);
	}
	fclose(file_ptr);
	
	//open output file
	file_ptr = fopen(output_filename, "wb");
	if (file_ptr==NULL) {
		printf("can't open file %s for binary writing, exiting...\n", output_filename);
		exit(1);
	}
	else printf("opened output file %s\n", output_filename);

	//write ppm header
    fprintf(file_ptr, "P6\n%d %d\n255\n", width, height);

	//write ppm image, pixel order is across first, then down, color order is RGB
	for (i=0; i<height; i++) for (j=0; j<width; j++) {
		fputc(r_image[width*i+j], file_ptr);
		fputc(g_image[width*i+j], file_ptr);
		fputc(b_image[width*i+j], file_ptr);
	}
	
	free(r_image);
	free(g_image);
	free(b_image);
	fclose(file_ptr);
	printf("done :)\n");
	return 0;
}
