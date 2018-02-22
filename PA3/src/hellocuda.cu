///////////////////////////////////////////////////////////////////////////////
//////////////////// kNN implementation main file /////////////////////////////
///////////////////// Written by Eric Li //////////////////////////////////////

//Includes
#include <cstdio>
#include <iostream>
#include <time.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "knn.h"
//define error macro
#define HANDLE_ERROR(func) { GPUAssert((func), __FILE__, __LINE__);}
inline void GPUAssert( cudaError_t errCode, const char *file, int line, bool abort=true)
    {
     if( errCode != cudaSuccess )
         {
          fprintf(stderr, "GPUAssert: %s %s %d\n", cudaGetErrorString(errCode), file, line);
          if (abort) exit(errCode);
         }
    }

//main function
int main(int argc, char const *argv[])
{
   //initialize variables
   FILE * fp;
   int rows, cols;
   float *inData, *partial, *sortArray; 
   char* buffer;
   char* charBuffer;
   size_t len;
   char* str;
   //ask user for dimension of input data matrix
   std::cout << " Please enter amount of rows desired to read in: ";
   std::cin >> rows;
   
   std::cout << " Please enter amount of columns desired to read in: ";
   std::cin >> cols;

   //allocate Unified memory for input data storage
   HANDLE_ERROR( cudaMallocManaged( &inData, rows*cols*sizeof(float)) );
   HANDLE_ERROR( cudaMallocManaged( &partial, rows*cols*sizeof(float)) );
   HANDLE_ERROR( cudaMallocManaged( &sortArray, rows*sizeof(float)) );
   
   //allocate memory for read buffer
   buffer = (char*) malloc(cols*sizeof(double));
   charBuffer = (char*) malloc(20*sizeof(double));
   //open file and read in data
   fp = fopen("../src/PA3_nrdc_data.csv", "r");
   
   //test for successful file opening
   if(fp){
      std::cout << std::endl << "Printing buffer vals: ";
      for(int i = 0; i < cols; i++){
         //fgets(buffer, rows*sizeof(float), fp);
         getdelim(&charBuffer, &len, ',',fp);
         inData[ i*cols ] = charBuffer;
         /*for(int j = 0; j < cols; j++){
            getdelim(&charBuffer) 
         }*/

      
        str = strtok( charBuffer, ",");
        std::cout << ' ' << str;
        std::cout << ' ' << std::strtod(str, NULL);
      }
     //std::fin.ignore(' '); 
     


     /*getdelim(&buffer2, &len, ' ,', fp);
     fgets(buffer, cols*sizeof(char), fp);
     std::cout << std::endl << "This is the string printed: " << buffer;
     str = strtok(buffer, " ,");
     std::cout << std::endl << "This is the string printed: " << str ;
     std::cout << std::endl << "This is the buffer2 printed: " << buffer2 ;*/
   }
   else{
      std::cout << std::endl << "File opening error, please try again";
   }
   //read in data from file
   fclose(fp);



   //free memory
   cudaFree(inData);
   cudaFree(partial);
   cudaFree(sortArray);
   free(buffer);
   free(charBuffer);
   return 0;
}