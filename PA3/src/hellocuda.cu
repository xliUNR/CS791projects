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
//Define compare function used for qsort
int compareFunc( const void *a, const void *b){
  float *x = (float*)a;
  float *y = (float*)b;
  if( *x < *y ) return -1;
  else if(*x > *y) return 1; return 0;
}
///////////////////////////////////////////////////////////////////////////////
//main function
int main(int argc, char const *argv[])
{
   //initialize variables
   //file pointer for reading data from file
   FILE * fp;
   int rows, readCols, paddedCols, numEmpty, knnCtr, knnIdx;
   float *inData, *partial, *GPUsortArr, *CPUsortArr;
   float accum, partResult, avg; 
   char* charBuffer;
   char* str;
   char* endlineBuffer;
   size_t len;
 
   
   //ask user for dimension of input data matrix
   std::cout << " Please enter amount of rows desired to read in: ";
   std::cin >> rows;
   
   std::cout << " Please enter amount of columns desired to read in: ";
   std::cin >> readCols;

   //set padded columns to read columns.
   paddedCols = readCols;

   //Check to see if number of columns is odd, need to pad in that case for reduction
   if( paddedCols % 2 != 0 ){
     paddedCols+=1;
     }

   /*
     This line checks to see if number of columns-2 is a power of 2. 
     Need to pad for reduction if not. First two columns are ignored b/c 1st
     is id and 2nd is column with holes, so these are not involved in calc
   */  
   while( ceil(log2((float)paddedCols-2)) != floor(log2((float)paddedCols-2)) ){
     paddedCols+=2;
   }

   //declare grid structure
   dim3 grid(64);
   //dim3 block((cols+32/32));

   //allocate Unified memory for input data storage
   HANDLE_ERROR( cudaMallocManaged( &inData, rows*readCols*sizeof(float)) );
   HANDLE_ERROR( cudaMallocManaged( &partial, rows*paddedCols*sizeof(float)) );
   HANDLE_ERROR( cudaMallocManaged( &GPUsortArr, rows*sizeof(float)) );
   
   //initialize partial array with zeros, this is essentially the padding step
   for(int i=0; i < rows*paddedCols; i++){
     partial[i] = 0;
   } 

   //allocate CPU memory
   charBuffer = (char*) malloc(20*sizeof(double));
   endlineBuffer = (char*) malloc(100*sizeof(double));
   CPUsortArr = (float*) malloc(rows*sizeof(float));
   //open file and read in data
   fp = fopen("../src/PA3_nrdc_data.csv", "r");
   
   //test for successful file opening
   if(fp){
      //std::cout << std::endl << "Printing buffer vals: ";
      for(int i = 0; i < rows; i++){
         //read in first value, discard and put index i instead as the first column
         getdelim(&charBuffer, &len, ',' ,fp);
         str = strtok( charBuffer, ",");
         inData[ i*readCols ] = (float)i;

         //loop over all columns and input value into 1D array
         for(int j = 1; j < readCols; j++){
            getdelim(&charBuffer, &len, ',',fp);
            str = strtok( charBuffer, ",");
            inData[ i*readCols+j ] = std::strtod(str,NULL);
           } 
         //skip until endline  
         getdelim(&endlineBuffer, &len, '\n', fp); 
        }
     }
   //else print error message and exit 
   else{
      std::cout << std::endl << "File opening error, please try again";
      exit(1);    
    }

  //close file 
  fclose(fp); 

   //make some missing values (10%), the first 10% of rows
   numEmpty = (rows <= 10) ? 1: (rows/10);

   for(int i = 0; i < numEmpty; i++){
       inData[ i*readCols+1] = -1;
   }   
  //////////////////////////////////////////////////////////////////////////
  //////////////////// sequential Implementation  //////////////////////////
  //make event timing variables
  cudaEvent_t hstart, hend;
  cudaEventCreate(&hstart);
  cudaEventCreate(&hend);
  cudaEventRecord( hstart, 0 );

  //outermost loop is to loop over all rows
  for(int i=0; i < rows; i++){
    //look for columns that are missing value, which is denoted by a -1
    if( inData[ i*readCols + 1] == -1 ){
      //loop over all rows again for nearest neighbor calc
      for(int j=0; j < rows; j++){
        //set accumulator to 0. This will store partial results from dist
        accum = 0;
        //This time checking for nonempty rows to calculate the
        if( inData[ j*readCols +1 ] != -1){
          //loop over columns and calculate partial distance then sum into
          //accumulator
          for(int k = 2; k < readCols; k++){
            partResult = inData[ i*readCols + k ] - inData[ j*readCols + k ];
            partResult *= partResult;
            accum += partResult;
          }
          //square root accumulator to get distance
          accum = sqrt(accum);
        }
        //store accum value. 0 for rows w/ holes. Distance for other
        CPUsortArr[ j ] = accum;
      }
      //printing CPUsort Arr
      /*std::cout << std::endl << "CPUsortArr for row" << i << ": ";
      for(int m = 0; m < rows; m++){
        std::cout << CPUsortArr[m] << std::endl; 
      }*/
      //use qsort from stdlib. 
      qsort(CPUsortArr, rows, sizeof(float), compareFunc);
      //Then find k = 5 nearest neighbors. Average then
      //deposit back into inMat.
      knnCtr = 0;
      knnIdx = 0;
      avg = 0;
      while( knnCtr < 5 && knnIdx < rows ){
        if( CPUsortArr[ knnIdx ] != 0 ){
          avg+=CPUsortArr[ knnIdx ];
          knnCtr++;
        }
        knnIdx++;
      }
      //divide by 5 to get average
      avg /=5;
      //Print results
      std::cout << std::endl << "CPU Imputed Index: " << i; 
      std::cout << " CPU Imputed Value: " << avg; 
    }
  }
  //stop timing
  cudaEventRecord( hend, 0 );
  cudaEventSynchronize( hend );
  float cpuTime;
  cudaEventElapsedTime( &cpuTime, hstart, hend);
  //////////////////////////////////////////////////////////////////////////
  /////////////// parallel Implementation /////////////////////////////////   
  //start event timer for GPU parallel implementation 
  cudaEvent_t start, end;
  cudaEventCreate(&start);
  cudaEventCreate(&end);
  cudaEventRecord( start, 0 );

  //loop over all rows
  for(int i=0; i < rows; i++){
    //If row needs to be imputed, will execute GPU kernel
    if( inData[ i*readCols + 1] == -1){
      /*
        kernel call to knnDist which calculates the partial distance between 
        the row to be imputed with every other row and returns a partial matrix with 
        distances stored in the second col of each row. This value still needs to be
        square rooted to get the distance. 
      */  
      knnDist<<<grid,32>>>(inData, partial, i, rows, readCols, paddedCols);
      //error checking for kernel call
      HANDLE_ERROR( cudaPeekAtLastError() );
      HANDLE_ERROR( cudaDeviceSynchronize() );

      /*
        this kernel squares results stored in col 2 of partial and transfers distance 
        into 1D array for sorting on CPU
      */  
      distXfer<<<1,32>>>(partial, GPUsortArr, rows, paddedCols);
      //error checking for kernel call
      HANDLE_ERROR( cudaPeekAtLastError() );
      HANDLE_ERROR( cudaDeviceSynchronize() );
      //print GPU sort array
      /*std::cout << std::endl << "GPUsortArr for row" << i << ": ";
      for(int m = 0; m < rows; m++){
        std::cout << GPUsortArr[m] << std::endl; 
      }*/
      //sort array
      qsort(GPUsortArr, rows, sizeof(float), compareFunc);
      //Then find k = 5 nearest neighbors. Average then print.
      knnCtr = 0;
      knnIdx = 0;
      avg = 0;
      while( knnCtr < 5 && knnIdx < rows ){
        if( GPUsortArr[ knnIdx ] != 0 ){
          avg+=GPUsortArr[ knnIdx ];
          knnCtr++;
        }
        knnIdx++;
      }
      //divide by 5 to get average
      avg /=5;
      //print results
      std::cout << std::endl << "GPU Imputed Index: " << i; 
      std::cout << "  GPU Imputed Value: " << avg; 
    }
  }
  cudaEventRecord( end, 0 );
  cudaEventSynchronize( end );

  float elapsedTime;
  cudaEventElapsedTime( &elapsedTime, start, end );

  //print out program stats
  std::cout << std::endl << "Your program took: " << elapsedTime << " ms." 
                                                                << std::endl;
  std::cout << "The CPU took: " << cpuTime << "ms " << std::endl;

   //free memory
   cudaFree(inData);
   cudaFree(partial);
   cudaFree(GPUsortArr);
   free(charBuffer);
   free(endlineBuffer);
   free(CPUsortArr);
   return 0;
}



