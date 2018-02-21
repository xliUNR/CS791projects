///////////////////////////////////////////////////////////////////////////////
////////////// Device code for PA3: kNN data Imputation    ////////////////////
//////////////////////////  written by Eric Li ////////////////////////////////
////////////////////////////////////////////////////////////////////////////// 

#include "knn.c"

/*
  This is the main function that performs the kNN algorithm.
*/

__global__ void kNN( float *inputMat, float *partialMat, int imputIndex, 
                                                           int rows, int cols){
   //initialize variables
   int blockIdx, tidx, partialIndex, reduceThreads, sumIdx;
   float diff;
   /*
     calculate unique index in matrix. This is so that each thread can access
     the correct memory location corresponding to it's data point. This index 
     is calculated from the size of the array and the block index and thread 
     indices of each thread.
   */  
   bidx = blockIdx.x;
   reduceThreads = cols / 2;

   while( bidx < rows )
      {  
         //calc thread index in partial matrix
         tidx = bidx * cols + threadIdx.x + 2;

         //Calculate offset of input matrix
         Emptyoffset = ( bidx * blockDim.x + 2 )*sizeof(int);
         EmptyoffsetIndex = ( bidx * blockDim.x + 2 );
         /*
           test to see if block ( time ) has an empty, if it is empty then threads must idle because their calculation would be useless.
         */
         if( (*inputMat + Emptyoffset) > 0 ){
            while( tidx < cols )
               {  
                  diff = inputMat[imputIndex] - inputMat[tidx];
                  partialMat[tidx] = diff * diff;
                  //stride threads to next set of operations
                  tidx = tidx + blockDim.x;
               }
         //sync threads b4 reduction 
         __syncthreads();         
      
      //do reduction summation  
         //reset tidx from thread striding above
         tidx = bidx*cols + threadIdx.x + 2;  
         /*
           Calculate the index of element to be summed in reduction. 
           This will be a block size over to ensure no threads are summing
           element belonging to other thread. 
         */
         sumIdx = tidx + blockDim.x;
         /*
           stride loop for summing. The first block size number of
           threads will hold the sums. Then this will be reduced.
         */
         while( sumIdx < cols )
            {  
               /*
                 caclulate index of partial matrix that the reduction 
                 results are stored in, then sum and stride to next row
               */  
               reduceIndex = bidx * rows + tidx;
               partialMat[ reduceIndex ] += partialMat[ sumIdx ];
               tidx+=blockDim.x;             
            }
            __syncthreads();
            reduceThreads /= 2;   

      //thread reduction step
         //reset tidx
         tidx = bidx*cols + threadIdx.x + 2;      
         reduceThreads = blockDim.x / 2;
         while( reduceThreads > 0 )
            {
               /*
                 Have to add 2 b/c of tidx offset due to first two cols being
                 ignored
               */
               if( tidx < reduceThreads + 2 )
                  {
                     partialMat[ tidx ] += partialMat[ tidx + reduceThreads ];
                  }
               reduceThreads /= 2;   
            }

            /*
              Square root results of summation to get distance 
            */
            partialMat[ (bidx * cols + 2) ] = 
                                   sqrt( partialMat[ (bidx * cols + 2) ] );
         }
        
         //stride to next set of blocks
         blockIdx = blockIdx + gridDim.x;   
      }

/*
  this function will transfer the second col of each row into an array so
  that sorting can be done on CPU
*/
__global__ void distXfer( float* inMat, float* outArr, int rows, int cols ){
   int bidx, tidx;
   bidx = blockIdx.x;
   tidx = bidx * cols + threadIdx.x;
   while( bidx < rows ){
      outArr[ bidx ] = inMat[ (bidx * cols + 2) ];
      bidx += blockDim.x;
   }
}     



__global__ void reduceMin( int* inMat){
   int reduceThreads, reduceIndex;
   bool swapped;
   reduceIndex = blockIdx.x * cols + 2;

   reduceThreads = rows / 2;

   while( reduceThreads > 5 )
      {
         atomicMin(&(inMat[reduceIndex]), 
                              inputMat[ reduceIndex + reduceThreads]);
         __syncthreads();
         reduceThreads /= 2;
      }
}  

///////////////////////////////////////////////////////////////////////////////
////////////////////////// helper functions ///////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
