// Convert a raw framebuffer into a bitmap

#include <stdio.h>
#include <stdlib.h>

struct DIBHeader {
	int size;	/* Size of this header structure */
	int width;
	int height;
	short planes;
	short bitCount;
	int compression;
	int imageSize;
	int xPelsPerMeter;
	int yPelsPerMeter;
	int colorsUsed;
	int importantColors;
};

void writeBmp(const char *filename, void *pixelData, int width, int height)
{
	FILE *file;
	char fileHeader[14];
	struct DIBHeader dibHeader;
	int fileSize = width * 4 * height + 14 + sizeof(struct DIBHeader);
	int bitsOffset;

	memset(fileHeader, 0, sizeof(fileHeader));
	fileHeader[0] = 'B';
	fileHeader[1] = 'M';
	fileHeader[2] = fileSize & 0xff;
	fileHeader[3] = (fileSize >> 8) & 0xff;
	fileHeader[4] = (fileSize >> 16) & 0xff;
	fileHeader[5] = (fileSize >> 24) & 0xff;

	bitsOffset = 14 + sizeof(dibHeader);
	fileHeader[10] = bitsOffset & 0xff;
	fileHeader[11] = (bitsOffset >> 8) & 0xff;
	fileHeader[12] = (bitsOffset >> 16) & 0xff;
	fileHeader[13] = (bitsOffset >> 24) & 0xff;

	file = fopen(filename, "wb+");
	if (file == NULL) {
		printf("error opening output file\n");
	}

	fwrite(fileHeader, 14, 1, file);

	dibHeader.size = sizeof(dibHeader);	/* Size of this header structure */
	dibHeader.width = width;
	dibHeader.height = height;
	dibHeader.planes = 1;
	dibHeader.bitCount = 32;
	dibHeader.compression = 0;
	dibHeader.imageSize = width * height * 4;
	dibHeader.xPelsPerMeter = 0;
	dibHeader.yPelsPerMeter = 0;
	dibHeader.colorsUsed = 0;
	dibHeader.importantColors = 0;

	fwrite(&dibHeader, sizeof(dibHeader), 1, file);
	fwrite(pixelData, dibHeader.imageSize, 1, file);

	fclose(file);
}

void *readFile(const char *filename)
{
	FILE *f;
	int length;
	void *buffer;
	
	f = fopen(filename, "rb");
	if (f == NULL)
	{
		perror("readFile: readFile ");
		exit(1);
	}
	
	fseek(f, 0, SEEK_END);
	length = ftell(f);
	fseek(f, 0, SEEK_SET);
	
	buffer = malloc(length);
	if (fread(buffer, length, 1, f) <= 0)
	{
		perror("readFile: fread ");
		exit(1);
	}
	
	fclose(f);
	
	return buffer;
}

// usage: mkbmp <inputfile> <outputfile.bmp> <width> <height>
int main(int argc, const char *argv[])
{
	void *rawData;
	
	if (argc != 5)
	{
		printf("usage: mkbmp <inputfile> <outputfile.bmp> <width> <height>\n");
		return 0;
	}
	
	rawData = readFile(argv[1]);
	writeBmp(argv[2], rawData, atoi(argv[3]), atoi(argv[4]));

	return 0;
}
