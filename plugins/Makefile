SRCS := $(wildcard *.cpp)
OBJS := $(patsubst %.cpp,%.so,$(SRCS))

.PHONY: all clean

all: $(OBJS)

%.so: %.cpp
	$(CXX) -shared -Wall -fPIC $^ -o $@

clean:
	rm *.so
