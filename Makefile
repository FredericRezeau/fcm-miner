CXX = g++
NVCC = nvcc

CXXFLAGS = -O3 -march=native -DNDEBUG -flto -ffast-math -funroll-loops \
           -fopenmp -pthread -std=c++17 -Iutils
NVCCFLAGS = -O3 -std=c++17 -Iutils

TARGET = miner
SRCS = miner.cpp

OBJS = miner.o
GPU ?= 0

ifeq ($(GPU),1)
    CXXFLAGS += -DGPU=1
    CUDA_SRCS = kernel.cu
    CUDA_OBJS = kernel.o
    OBJS += kernel.o
    LINKER = $(NVCC)
    LDFLAGS =
else
    CUDA_SRCS =
    CUDA_OBJS =
    LINKER = $(CXX)
    LDFLAGS =
endif

all: $(TARGET)

$(TARGET): $(OBJS)
	$(LINKER) -o $(TARGET) $(OBJS) $(LDFLAGS)

clean:
	rm -f $(TARGET) $(OBJS)

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

%.o: %.cu
	$(NVCC) $(NVCCFLAGS) -c $< -o $@

.PHONY: all clean
