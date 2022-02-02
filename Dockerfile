FROM ubuntu:trusty

RUN apt-get update &&                                                              \
    apt-get -y upgrade &&                                                          \
    apt-get install -y wget make mingw-w64 unzip xz-utils subversion git pkg-config bison flex

ENV PCRE_VERSION=8.45
ENV ICONV_VERSION=1.16
ENV EXPAT_VERSION=2.4.1
ENV GETTEXT_VERSION=0.19.8
ENV LIBFFI_VERSION=3.2

WORKDIR /root
RUN wget --no-check-certificate https://sourceforge.net/projects/pcre/files/pcre/$PCRE_VERSION/pcre-$PCRE_VERSION.tar.bz2 && \
    wget --no-check-certificate https://ftp.gnu.org/pub/gnu/libiconv/libiconv-$ICONV_VERSION.tar.gz &&    \
    wget --no-check-certificate http://downloads.sourceforge.net/expat/expat-$EXPAT_VERSION.tar.gz &&     \
    wget --no-check-certificate https://ftp.gnu.org/gnu/gettext/gettext-$GETTEXT_VERSION.tar.gz &&        \
    wget --no-check-certificate ftp://sourceware.org/pub/libffi/libffi-$LIBFFI_VERSION.tar.gz

RUN tar xf pcre-$PCRE_VERSION.tar.bz2 &&                                            \
    tar xf libiconv-$ICONV_VERSION.tar.gz &&                                       \
    tar xf expat-$EXPAT_VERSION.tar.gz &&                                          \
    tar xf gettext-$GETTEXT_VERSION.tar.gz &&                                      \
    tar xf libffi-$LIBFFI_VERSION.tar.gz 

ARG TARGET=x86_64 # or i686
ARG MINGWDIR=/usr/lib/gcc/x86_64-w64-mingw32/4.8/
  
RUN cd /root/pcre-$PCRE_VERSION &&                                              \
    CC=$TARGET-w64-mingw32-gcc CC_FOR_BUILD=gcc  ./configure                    \
      --host=$TARGET-w64-mingw32                                                \
      --enable-utf8 --enable-unicode-properties --enable-jit                    \
      --enable-newline-is-any --disable-cpp --enable-static                     \
      --disable-dependency-tracking                                             \
      --prefix=$MINGWDIR                          \
      --exec-prefix=$MINGWDIR                     \
      --libdir=$MINGWDIR                    \
      --oldincludedir=$MINGWDIR/include &&        \
    make && make install && make clean

RUN cd /root/libiconv-$ICONV_VERSION &&                                         \
    CC=$TARGET-w64-mingw32-gcc CC_FOR_BUILD=gcc ./configure                     \
      --host=$TARGET-w64-mingw32                                                \
      --enable-static                                                           \
      --prefix=$MINGWDIR                          \
      --exec-prefix=$MINGWDIR                     \
      --libdir=$MINGWDIR                      \
      --oldincludedir=$MINGWDIR/include &&        \
    make && make install && make clean
    
RUN cd /root/expat-$EXPAT_VERSION &&                                            \
    CC=$TARGET-w64-mingw32-gcc CC_FOR_BUILD=gcc ./configure                     \
      --host=$TARGET-w64-mingw32                                                \
      --prefix=$MINGWDIR                          \
      --exec-prefix=$MINGWDIR                     \
      --libdir=$MINGWDIR                      \
      --oldincludedir=$MINGWDIR/include &&        \
    make && make install && make clean

RUN cd /root/gettext-$GETTEXT_VERSION &&                                        \
    CC=$TARGET-w64-mingw32-gcc CC_FOR_BUILD=gcc ./configure                     \
      --enable-static                                                           \
      --enable-shared \
      --disable-threads                                                         \
      --host=$TARGET-w64-mingw32                                                \
      --prefix=$MINGWDIR                          \
      --exec-prefix=$MINGWDIR                     \
      --libdir=$MINGWDIR                      \
      --oldincludedir=$MINGWDIR/include &&        \
      make && make install && make clean; exit 0

RUN cd /root/libffi-$LIBFFI_VERSION &&                                          \ 
    LIBFFI_CFLAGS=${MINGW_OUTPUT}/include                                       \
    LIBFFI_LIBS=${MINGW_OUTPUT}/include                                         \
    CC=$TARGET-w64-mingw32-gcc CC_FOR_BUILD=gcc                                 \
    ./configure                                                                 \
    --host=$TARGET-w64-mingw32                                                  \
    --prefix=$MINGWDIR                            \
    --exec-prefix=$MINGWDIR                       \
    --libdir=$MINGWDIR                        \
    --oldincludedir=$MINGWDIR/include &&          \
    make && make install && make clean

RUN if [ "$TARGET" =  "x86_64" ]; then ARCH=64; else ARCH=32; fi && \
    cd /opt &&                                                                  \
    mkdir glib &&                                                               \
    cd glib &&                                                                  \
    wget --no-check-certificate https://download.gnome.org/binaries/win$ARCH/glib/2.26/glib-dev_2.26.0-1_win$ARCH.zip && \ 
    unzip glib-dev_2.26.0-1_win$ARCH.zip && \
    rm glib-dev_2.26.0-1_win$ARCH.zip && \
    sed -i -E "s/^prefix=.*$/prefix=\/opt\/glib/" /opt/glib/lib/pkgconfig/glib-2.0.pc


# re-setting CWB_BUILD can be used to trigger re-building docker from here if RcppCWB code has changed  
ARG CWB_BUILD=0006
WORKDIR /root
RUN svn co http://svn.code.sf.net/p/cwb/code/cwb --depth immediates && \
  cd cwb/trunk && \
  svn update --set-depth=immediates && \
  for dir in CQi  cl  config  cqp  editline  install-scripts  instutils  utils; do cd $dir; svn update --set-depth=infinity; cd ..; done

WORKDIR /root/cwb/trunk

RUN sed -i -E "s/^PLATFORM=.*$/PLATFORM=mingw-cross/" config.mk && \
  sed -i -E "s/^SITE=.*$/SITE=windows-release/" config.mk && \
  sed -i -E "s/#\s+CC\s*=\s*.*$/CC=x86_64-w64-mingw32-gcc/" config.mk && \
  sed -i -E 's|#\s+(LIBPCRE_DLL_PATH)\s+=.*$|LIBPCRE_DLL_PATH=$LIBDIR/|g' config.mk && \
  sed -i -E "s|#\s+(LIBGLIB_DLL_PATH)\s+=.*$|LIBGLIB_DLL_PATH=$LIBDIR/|g" config.mk

RUN sed -i -E "s/export\s*PKG_CONFIG_PATH=.+MINGW_CROSS_HOME.\/lib\/pkgconfig\s*;//g" definitions.mk && \
    sed -i -E "s/\s+\\$\\(MINGW_CROSS_HOME\\)\/bin\/pcre-config/ pcre-config/g" definitions.mk && \
    sed -i -E "s/^CFLAGS_ALL\s=/CFLAGS_ALL = -DPCRE_STATIC=-1 -DGLIB_STATIC_COMPILATION/g" definitions.mk && \
    sed -i -E "s/^#PCRE_DEFINES/PCRE_DEFINES/" definitions.mk && \
    sed -i -E "s/^#GLIB_DEFINES/GLIB_DEFINES/" definitions.mk && \
    sed -i -E "s/PCRE_DEFINES\s:=\s-DPCRE_STATIC//" definitions.mk
    
    
RUN sed -i -E "s/i586-mingw32msvc/x86_64-w64-mingw32/g" ./config/platform/mingw-cross && \
  sed -i -E "s/i586/x86_64/" ./config/platform/mingw-cross

# CMD cd /root/cwb/trunk/utils/; for file in $(ls *.exe); do echo $file; cp /root/cwb/trunk/utils/$file /utils/$file; done

RUN cd /root/cwb/trunk && \
  export PKG_CONFIG_PATH=/opt/glib/lib/pkgconfig && \
  export PATH=$PATH:$MINGWDIR/bin/ && \
  make clean && make depend && make cl && make utils
  
CMD cd /root/cwb/trunk/utils/; for file in $(ls *.exe); do echo $file; cp /root/cwb/trunk/utils/$file /utils/$file; done; \
  cp /usr/lib/gcc/x86_64-w64-mingw32/bin/libintl-9.dll  /utils/libintl-9.dll; \
  cp /usr/lib/gcc/x86_64-w64-mingw32/bin/libiconv-2.dll  /utils/libintl-2.dll;

