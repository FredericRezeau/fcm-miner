CXX = g++
NVCC = nvcc

COMMON_FLAGS = -O3 -DNDEBUG -ffast-math -funroll-loops \
               -fopenmp -pthread -std=c++17 -Iutils
GXX_FLAGS = $(COMMON_FLAGS) -march=native -flto
NVCC_FLAGS = $(COMMON_FLAGS)

TARGET = miner

GPU ?= 0

ifneq ($(filter 1 CUDA,$(GPU)),)
    CXXFLAGS = $(GXX_FLAGS) -DGPU=1
    NVCCFLAGS += -DGPU=1
    SRCS = miner.cpp kernel.cu
    OBJS = miner.o kernel.o
    LINKER = $(NVCC)
    LDFLAGS =
else
    CXXFLAGS = $(GXX_FLAGS) -DGPU=0
    SRCS = miner.cpp
    OBJS = miner.o
    LINKER = $(CXX)
    LDFLAGS =
endif

all: $(TARGET)

$(TARGET): $(OBJS)
	$(LINKER) -o $@ $(OBJS) $(LDFLAGS)

clean:
	rm -f $(TARGET) $(OBJS)

miner.o: miner.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

kernel.o: kernel.cu
	$(NVCC) $(NVCCFLAGS) -c $< -o $@

.PHONY: all clean
