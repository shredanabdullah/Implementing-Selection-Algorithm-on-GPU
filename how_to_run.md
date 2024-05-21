how to run the GPU code

Name the file using %%writefile filtering.cu
then for compiling and running the file
!nvcc -o filtering filtering.cu
!./filtering

To see the output txt --> !cat output.txt



how to run the CPU code

%%writefile filtering_cpu.c
then for compiling and running the file
!gcc filtering_cpu.c -o filtering_cpu
!./filtering_cpu