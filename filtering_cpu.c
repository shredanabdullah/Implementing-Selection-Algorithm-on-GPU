#include <stdio.h>
#include <stdlib.h>

#define ARRAY_SIZE 1000000

int predicate_condition(int element) {
    return (element % 2 != 0) && (element >= 500 && element <= 510);
}


void filter(const int* data, int* result_array) {
    for (int i = 0; i < ARRAY_SIZE; ++i) {
        if (predicate_condition(data[i])) {
            result_array[i] = data[i];
        } else {
            result_array[i] = -1;
        }
    }
}


int compact(const int* result_array, int* final_output) {
    int count = 0;
    for (int i = 0; i < ARRAY_SIZE; ++i) {
        if (result_array[i] != -1) {
            final_output[count++] = result_array[i];
        }
    }
    return count; // return the count of valid elements
}
int main() {
    int* host_data = (int*)malloc(ARRAY_SIZE * sizeof(int));
    int* result_array = (int*)malloc(ARRAY_SIZE * sizeof(int));
    int* final_output = (int*)malloc(ARRAY_SIZE * sizeof(int));

    for (int i = 0; i < ARRAY_SIZE; ++i) {
        host_data[i] = ARRAY_SIZE - i;
    }
    filter(host_data, result_array);

    int valid_count = compact(result_array, final_output);
    // Sort the final_output using qsort
    qsort(final_output, valid_count, sizeof(int), compare);

    FILE *output_file = fopen("output.txt", "w");

    fprintf(output_file, "Elements satisfying the predicate condition:\n");
    for (int i = 0; i < valid_count; ++i) {
        fprintf(output_file, "%d\n", final_output[i]);
    }
    fclose(output_file);
    free(host_data);
    free(result_array);
    free(final_output);
    return 0;
}
