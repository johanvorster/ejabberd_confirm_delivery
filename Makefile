all:
	sh build.sh

install:
	cp ebin/*.beam /usr/lib64/ejabberd/ebin/

clean:
	rm ebin/*.beam
