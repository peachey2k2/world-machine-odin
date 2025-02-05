This is a rewrite of my [voxel engine](https://github.com/peachey2k2/raylib-voxel-game) which was written with C++ and Raylib.

## Building
This project uses [nob.h](https://github.com/tsoding/nob.h) which is a C based build system. To use it, you'll need to bootstrap it by compiling it like a regular c program:
```shell
cc -o nob nob.c
```
After that, you can just run `./nob build` to build it (it'll auto-update itself). There are a few other arguments to use with it, you can run `./nob help` to see them all.

