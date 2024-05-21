#include <stdio.h>
#include <stdlib.h>
#include <thrust/device_vector.h>
#include <thrust/copy.h>
#include <thrust/sort.h>
#include <thrust/execution_policy.h>
#include <cuda_runtime.h>

#define ARRAY_SIZE 1000000
#define THREADS_PER_BLOCK 256
#define TILE_SIZE 256 // tile size for the shared memory

// Predicate condition
__device__ bool predicate_condition(int element) {
    return (element % 2 != 0) && (element >= 50 && element <= 60);
}

__global__ void filter_kernel(const int* data, int* result_array, int size) {
    __shared__ int tile[TILE_SIZE]; // Declaring the shared memory tile
    int tid = threadIdx.x + blockIdx.x * blockDim.x; // Calculating global thread ID

    // Checking if thread is within bounds
    if (tid < size) {
        tile[threadIdx.x] = data[tid]; // Loading data into shared memory
        __syncthreads(); // Synchronizing threads within the block

        // Checking if element satisfies predicate condition
        if (predicate_condition(tile[threadIdx.x])) {
            result_array[tid] = tile[threadIdx.x]; // If true, write element to result array
        } else {
            result_array[tid] = -1; // If not, write -1 to result array
        }
    }
}

__global__ void compact_kernel(const int* result_array, int* final_output, int* count, int size) {
    __shared__ int tile[TILE_SIZE]; // Shared memory for the tile
    __shared__ int tile_count; // Shared memory for counting valid elements in the tile

    int tid = threadIdx.x + blockIdx.x * blockDim.x; // Calculating global thread ID

    // Initialize shared memory count to 0
    if (threadIdx.x == 0) {
        tile_count = 0;
    }
    __syncthreads();

    // Load data into shared memory and check for valid elements
    if (tid < size) {
        if (result_array[tid] != -1) {
            int local_index = atomicAdd(&tile_count, 1);
            tile[local_index] = result_array[tid];
        }
    }
    __syncthreads();

    // Compact valid elements from shared memory to global memory
    if (threadIdx.x < tile_count) {
        int global_index = atomicAdd(count, 1);
        final_output[global_index] = tile[threadIdx.x];
    }
}

int main() {
    cudaStream_t stream1, stream2;
    cudaStreamCreate(&stream1);
    cudaStreamCreate(&stream2);

    // Allocate memory on the GPU for input data and result array
    int *data, *result_array, *final_output, *dev_count;
    cudaMalloc((void**)&data, ARRAY_SIZE * sizeof(int));
    cudaMalloc((void**)&result_array, ARRAY_SIZE * sizeof(int));
    cudaMalloc((void**)&final_output, ARRAY_SIZE * sizeof(int));
    cudaMalloc((void**)&dev_count, sizeof(int));

    // Allocate memory on the host (CPU) for input data
    int* host_data = (int*)malloc(ARRAY_SIZE * sizeof(int));
    // Initialize input data with values from 1000000 to 1 (unsorted)
    for (int i = 0; i < ARRAY_SIZE; ++i) {
        host_data[i] = ARRAY_SIZE - i;
    }

    // Copy input data from host to device asynchronously using stream1
    cudaMemcpyAsync(data, host_data, ARRAY_SIZE * sizeof(int), cudaMemcpyHostToDevice, stream1);

    // Create Thrust device pointer and sort data on the GPU using stream1
    thrust::device_ptr<int> dev_ptr(data);
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);
    cudaEventRecord(start, stream1);
    thrust::sort(thrust::cuda::par.on(stream1), dev_ptr, dev_ptr + ARRAY_SIZE);

    // Launch the filter kernel on the GPU using stream1
    filter_kernel<<<(ARRAY_SIZE + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK, THREADS_PER_BLOCK, 0, stream1>>>(data, result_array, ARRAY_SIZE);
    cudaEventRecord(stop, stream1);
    cudaEventSynchronize(stop);
    float milliseconds;
    cudaEventElapsedTime(&milliseconds, start, stop);

    // Initialize device count to 0
    cudaMemsetAsync(dev_count, 0, sizeof(int), stream2);

    // Launch the compact kernel on the GPU using stream2
    compact_kernel<<<(ARRAY_SIZE + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK, THREADS_PER_BLOCK, 0, stream2>>>(result_array, final_output, dev_count, ARRAY_SIZE);

    // Allocate memory on the host for the final output array and count
    int* host_final_output = (int*)malloc(ARRAY_SIZE * sizeof(int));
    int host_count;

    // Copy the final output array and count from device to host asynchronously using stream2
    cudaMemcpyAsync(host_final_output, final_output, ARRAY_SIZE * sizeof(int), cudaMemcpyDeviceToHost, stream2);
    cudaMemcpyAsync(&host_count, dev_count, sizeof(int), cudaMemcpyDeviceToHost, stream2);

    // Synchronize stream2 to ensure all operations are complete before accessing the results
    cudaStreamSynchronize(stream2);

    FILE *output_file = fopen("output.txt", "w");

    // Write the elements satisfying the predicate condition to the output file
    fprintf(output_file, "Elements satisfying the predicate condition:\n");
    for (int i = 0; i < host_count; ++i) {
        fprintf(output_file, "%d\n", host_final_output[i]);
    }

    fprintf(output_file, "Time taken for analysis: %f milliseconds\n", milliseconds);

    fclose(output_file);

    
    cudaFree(data);
    cudaFree(result_array);
    cudaFree(final_output);
    cudaFree(dev_count);

    
    cudaStreamDestroy(stream1);
    cudaStreamDestroy(stream2);

    free(host_data);
    free(host_final_output);

    return 0;
}
