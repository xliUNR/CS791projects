/*
  This header demonstrates how we build cuda programs spanning
  multiple files. 
 */

#ifndef ADD_H_
#define ADD_H_

// This is the number of elements we want to process.


// This is the declaration of the function that will execute on the GPU.
__global__ void add(int n, int*, int*, int*);

__global__ void strideAdd(int n, int *, int *, int *);
//__global__ void mat_init( int N, int* );

#endif // ADD_H_
