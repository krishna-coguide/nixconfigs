// Run explicitly on a GPU host: enumerate, launch a kernel, verify device output.
#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>

static void check(cudaError_t result, const char *operation) {
    if (result != cudaSuccess) {
        std::fprintf(stderr, "%s: %s\n", operation, cudaGetErrorString(result));
        std::exit(EXIT_FAILURE);
    }
}

__global__ void answer(int *value) { *value = 42; }

int main() {
    int count = 0;
    check(cudaGetDeviceCount(&count), "CUDA device discovery (check the loaded NVIDIA driver)");
    if (count == 0) {
        std::fprintf(stderr, "No CUDA device is available; a toolkit install alone is not a GPU.\n");
        return EXIT_FAILURE;
    }
    for (int device = 0; device < count; ++device) {
        check(cudaSetDevice(device), "select device");
        cudaDeviceProp properties{};
        check(cudaGetDeviceProperties(&properties, device), "read device properties");
        int *gpu = nullptr;
        check(cudaMalloc(&gpu, sizeof(int)), "allocate device memory");
        answer<<<1, 1>>>(gpu);
        check(cudaGetLastError(), "launch kernel");
        check(cudaDeviceSynchronize(), "synchronize kernel");
        int value = 0;
        check(cudaMemcpy(&value, gpu, sizeof(int), cudaMemcpyDeviceToHost), "copy result");
        check(cudaFree(gpu), "free device memory");
        if (value != 42) return EXIT_FAILURE;
        std::printf("PASS GPU %d: %s (compute %d.%d), kernel result %d\n",
                    device, properties.name, properties.major, properties.minor, value);
    }
    return EXIT_SUCCESS;
}
