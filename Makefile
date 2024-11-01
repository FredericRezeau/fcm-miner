CXX = g++
CXXFLAGS = -O3 -march=native -DNDEBUG -flto -ffast-math -funroll-loops -fopenmp -mavx2 -pthread -std=c++17
TARGET = miner
SRCS = miner.cpp
OBJS = $(SRCS:.cpp=.o)

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CXX) $(CXXFLAGS) -o $(TARGET) $(OBJS)

clean:
	rm -f $(TARGET) $(OBJS)

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

.PHONY: all clean
