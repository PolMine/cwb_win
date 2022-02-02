# What

This is a very experimental package to make cwb utilities for building corpora available for Windows by way of crosscompilation. A docker container is used for this purpose. Build it using the following snippet and run it once, then updated files will be in this repository. Note that the path may need to be updated.

The resulting *.exe files are not standalone files (yet). Dynamic libraries that are required are copied into the repository. The glib-2.0 library has been downloaded from gnome. 

# How to do it

```{sh}
docker build -t cwbcross:utils .
```

```{sh}
docker run -it --rm -v /Users/andreasblaette/Lab/github/cwb_win/utils:/utils cwbcross:utils 
```
