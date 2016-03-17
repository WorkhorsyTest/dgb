

all: clean
	dmd -g -w -O -ofmain helpers.d backtrace.d main.d types.d sdl.d -L-lSDL

clean:
	rm -f main *.o *~ core
