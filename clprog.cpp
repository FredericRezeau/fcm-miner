/*
    MIT License
    Author: Fred Kyung-jin Rezeau <fred@litemint.com>, 2024
    Permission is granted to use, copy, modify, and distribute this software for any purpose
    with or without fee.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
*/

#define CL_TARGET_OPENCL_VERSION 300

#include <CL/cl.h>
#include <iostream>
#include <fstream>
#include <vector>
#include <cstdint>
#include <cstring>
#include <cstdlib>

#define CL_CALL(call)                                                               \
    do {                                                                            \
        cl_int err = call;                                                          \
        if (err != CL_SUCCESS) {                                                    \
            std::cout << "OpenCL Error in " << __FILE__ << ", line " << __LINE__    \
                      << ": Error Code " << err << std::endl;                       \
            exit(EXIT_FAILURE);                                                     \
        }                                                                           \
    } while (0)

void releaseResources(cl_context context, cl_command_queue commandQueue, cl_program program,
    cl_kernel kernel, cl_mem* buffers, int bufferCount) {
    for (int i = 0; i < bufferCount; i++) {
        if (buffers[i]) clReleaseMemObject(buffers[i]);
    }
    if (kernel) clReleaseKernel(kernel);
    if (program) clReleaseProgram(program);
    if (commandQueue) clReleaseCommandQueue(commandQueue);
    if (context) clReleaseContext(context);
}

extern "C" int executeKernel(std::uint8_t* data, int dataSize, std::uint64_t startNonce, int nonceOffset, std::uint64_t batchSize,
    int difficulty, int threadsPerBlock, std::uint8_t* output, std::uint64_t* validNonce, bool showDeviceInfo) {
    cl_int error;
    cl_platform_id platformId = nullptr;
    cl_device_id deviceId = nullptr;
    cl_uint numDevices;
    cl_uint numPlatforms;

    CL_CALL(clGetPlatformIDs(1, &platformId, &numPlatforms));
    CL_CALL(clGetDeviceIDs(platformId, CL_DEVICE_TYPE_GPU, 1, &deviceId, &numDevices));

    if (showDeviceInfo) {
        char deviceName[256];
        cl_uint computeUnits;
        size_t maxWorkGroupSize;
        size_t maxWorkItemSizes[3];
        cl_ulong globalMemSize;
        CL_CALL(clGetDeviceInfo(deviceId, CL_DEVICE_NAME, sizeof(deviceName), deviceName, nullptr));
        CL_CALL(clGetDeviceInfo(deviceId, CL_DEVICE_MAX_COMPUTE_UNITS, sizeof(computeUnits), &computeUnits, nullptr));
        CL_CALL(clGetDeviceInfo(deviceId, CL_DEVICE_MAX_WORK_GROUP_SIZE, sizeof(maxWorkGroupSize), &maxWorkGroupSize, nullptr));
        CL_CALL(clGetDeviceInfo(deviceId, CL_DEVICE_MAX_WORK_ITEM_SIZES, sizeof(maxWorkItemSizes), &maxWorkItemSizes, nullptr));
        CL_CALL(clGetDeviceInfo(deviceId, CL_DEVICE_GLOBAL_MEM_SIZE, sizeof(globalMemSize), &globalMemSize, nullptr));
        std::cout << "Device: " << deviceName << std::endl;
        std::cout << "Compute units: " << computeUnits << std::endl;
        std::cout << "Max work group size: " << maxWorkGroupSize << std::endl;
        std::cout << "Max work item sizes: [" 
                    << maxWorkItemSizes[0] << ", " 
                    << maxWorkItemSizes[1] << ", " 
                    << maxWorkItemSizes[2] << "]" << std::endl;
        std::cout << "Global memory size: " << (globalMemSize / (1024 * 1024)) << " MB" << std::endl;
    }

    cl_context context = clCreateContext(nullptr, 1, &deviceId, nullptr, nullptr, &error);
    if (!context) {
        std::cerr << "Error: " << error << std::endl;
        return -1;
    }
    cl_command_queue commandQueue = clCreateCommandQueueWithProperties(context, deviceId, 0, &error);
    if (!commandQueue) {
        std::cerr << "Error: " << error << std::endl;
        releaseResources(context, commandQueue, nullptr, nullptr, nullptr, 0);
        return -1;
    }

    std::ifstream kernelFile("kernel.cl");
    std::ifstream keccakFile("utils/keccak.cl");
    if (!kernelFile.is_open() || !keccakFile.is_open()) {
        std::cerr << "Failed to load OpenCL kernel files." << std::endl;
        releaseResources(context, commandQueue, nullptr, nullptr, nullptr, 0);
        return -1;
    }
    std::string kernelSource((std::istreambuf_iterator<char>(kernelFile)), std::istreambuf_iterator<char>());
    std::string keccakSource((std::istreambuf_iterator<char>(keccakFile)), std::istreambuf_iterator<char>());
    kernelFile.close();
    keccakFile.close();
    std::string fullSource = keccakSource + "\n" + kernelSource;
    const char* sourceStr = fullSource.c_str();
    size_t sourceSize = fullSource.size();

    cl_program program = clCreateProgramWithSource(context, 1, &sourceStr, &sourceSize, &error);
    if (!program) {
        std::cerr << "Error: " << error << std::endl;
        releaseResources(context, commandQueue, program, nullptr, nullptr, 0);
        return -1;
    }
    error = clBuildProgram(program, 1, &deviceId, nullptr, nullptr, nullptr);
    if (error != CL_SUCCESS) {
        size_t logSize;
        clGetProgramBuildInfo(program, deviceId, CL_PROGRAM_BUILD_LOG, 0, NULL, &logSize);
        std::vector<char> buildLog(logSize);
        clGetProgramBuildInfo(program, deviceId, CL_PROGRAM_BUILD_LOG, logSize, buildLog.data(), NULL);
        std::cerr << "Kernel build error: " << std::endl << buildLog.data() << std::endl;
        releaseResources(context, commandQueue, program, nullptr, nullptr, 0);
        return -1;
    }
    cl_kernel kernel = clCreateKernel(program, "run", &error);
    if (!kernel || error != CL_SUCCESS) {
        std::cerr << "Error: " << error << std::endl;
        releaseResources(context, commandQueue, program, kernel, nullptr, 0);
        return -1;
    }

    cl_mem deviceDataBuffer = clCreateBuffer(context, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, dataSize * sizeof(cl_uchar), data, &error);
    cl_mem foundBuffer = clCreateBuffer(context, CL_MEM_READ_WRITE, sizeof(cl_int), nullptr, &error);
    cl_mem outputBuffer = clCreateBuffer(context, CL_MEM_WRITE_ONLY, 32 * sizeof(cl_uchar), nullptr, &error);
    cl_mem validNonceBuffer = clCreateBuffer(context, CL_MEM_WRITE_ONLY, sizeof(cl_ulong), nullptr, &error);
    cl_mem buffers[] = {deviceDataBuffer, foundBuffer, outputBuffer, validNonceBuffer};
    for (auto& buf : buffers) {
        if (!buf) {
            std::cerr << "Error allocating buffer." << std::endl;
            releaseResources(context, commandQueue, program, kernel, buffers, 4);
            return -1;
        }
    }
    cl_int foundValue = 0;
    error = clEnqueueWriteBuffer(commandQueue, foundBuffer, CL_TRUE, 0, sizeof(cl_int), &foundValue, 0, nullptr, nullptr);
    error |= clSetKernelArg(kernel, 0, sizeof(cl_int), &dataSize);
    error |= clSetKernelArg(kernel, 1, sizeof(cl_ulong), &startNonce);
    error |= clSetKernelArg(kernel, 2, sizeof(cl_int), &nonceOffset);
    error |= clSetKernelArg(kernel, 3, sizeof(cl_ulong), &batchSize);
    error |= clSetKernelArg(kernel, 4, sizeof(cl_int), &difficulty);
    error |= clSetKernelArg(kernel, 5, sizeof(cl_mem), &deviceDataBuffer);
    error |= clSetKernelArg(kernel, 6, sizeof(cl_mem), &foundBuffer);
    error |= clSetKernelArg(kernel, 7, sizeof(cl_mem), &outputBuffer);
    error |= clSetKernelArg(kernel, 8, sizeof(cl_mem), &validNonceBuffer);
    if (error != CL_SUCCESS) {
        std::cerr << "Error: " << error << std::endl;
        releaseResources(context, commandQueue, program, kernel, buffers, 4);
        return -1;
    }

    size_t maxWorkGroupSize;
    clGetDeviceInfo(deviceId, CL_DEVICE_MAX_WORK_GROUP_SIZE, sizeof(size_t), &maxWorkGroupSize, NULL);
    size_t localWorkSize = std::min(static_cast<size_t>(threadsPerBlock), maxWorkGroupSize);
    size_t globalWorkSize = ((batchSize + localWorkSize - 1) / localWorkSize) * localWorkSize;
    error = clEnqueueNDRangeKernel(commandQueue, kernel, 1, nullptr, &globalWorkSize, &localWorkSize, 0, nullptr, nullptr);
    if (error != CL_SUCCESS) {
        std::cerr << "Error: " << error << std::endl;
        releaseResources(context, commandQueue, program, kernel, buffers, 4);
        return -1;
    }

    clFinish(commandQueue);
    CL_CALL(clEnqueueReadBuffer(commandQueue, foundBuffer, CL_TRUE, 0, sizeof(cl_int), &foundValue, 0, nullptr, nullptr));
    if (foundValue == 1) {
        CL_CALL(clEnqueueReadBuffer(commandQueue, outputBuffer, CL_TRUE, 0, 32 * sizeof(cl_uchar), output, 0, nullptr, nullptr));
        CL_CALL(clEnqueueReadBuffer(commandQueue, validNonceBuffer, CL_TRUE, 0, sizeof(cl_ulong), validNonce, 0, nullptr, nullptr));
    }
    releaseResources(context, commandQueue, program, kernel, buffers, 4);
    return foundValue;
}
