# This file was automatically generated.
# Do not edit, you'll loose your changes anyway.
package Prima::Config;
use vars qw(%Config %Config_inst);

%Config_inst = (
  incpaths              => [ 'c:/usr/local/perl/580/lib/site_perl/5.8.0/os2/Prima/CORE','c:/usr/local/perl/580/lib/site_perl/5.8.0/os2/Prima/CORE/generic','c:/usr/local/perl/580/lib/5.8.0/os2/CORE' ],
  gencls                => 'c:/usr/local/perl/580/bin\\gencls.cmd',
  tmlink                => 'c:/usr/local/perl/580/bin\\tmlink.cmd',
  libname               => 'c:/usr/local/perl/580/lib/site_perl/5.8.0/os2/Prima.lib',
  dlname                => 'c:/usr/local/perl/580/lib/site_perl/5.8.0/os2/auto/Prima/PrimaDI.dll',
  ldpaths               => ['c:/usr/lib','C:/JAVA11/LIB','c:/usr/lib/mt','c:/usr/lib','c:/usr/local/perl/580/lib/site_perl/5.8.0/os2/auto/Prima'],
);

%Config = (
  ifs                   => '/',
  quote                 => '\'',
  platform              => 'os2',
  compiler              => 'emx',
  incpaths              => [ 'C:/home/Prima/include','C:/home/Prima/include/generic','c:/usr/local/perl/580/lib/5.8.0/os2/CORE' ],
  platform_path         => 'C:/home/Prima/os2',
  gencls                => '\'C:/USR/BIN/perl58.exe\' C:/home/Prima/utils/gencls.pl',
  tmlink                => '\'C:/USR/BIN/perl58.exe\' C:/home/Prima/utils/tmlink.pl',
  scriptext             => '.cmd',
  genclsoptions         => '--tml --h --inc',
  cc                    => 'gcc',
  cflags                => '-c -Zomf -Zmt -DDOSISH -DOS2=2 -DEMBED -I. -D_EMX_CRT_REV_=52 -Wall  -O2 -fomit-frame-pointer -malign-loops=2 -malign-jumps=2 -malign-functions=2 -s  ',
  cdebugflags           => '-g -O',
  cincflag              => '-I',
  cobjflag              => '-o',
  cdefflag              => '-D',
  cdefs                 => ['HAVE_CONFIG_H=1'],
  objext                => '.obj',
  lib                   => 'emxomf',
  liboutflag            => '-o',
  libext                => '.lib',
  libname               => 'C:/home/Prima/auto/Prima/Prima.lib',
  dlname                => 'C:/home/Prima/auto/Prima/PrimaDI.dll',
  dlext                 => '.dll',
  ld                    => 'gcc',
  ldflags               => ' -Zdll -Zomf -Zmt -Zcrtdll -Zlinker /e:2  ',
  lddefflag             => '',
  lddebugflags          => '-g',
  ldoutflag             => '-o',
  ldlibflag             => '-l',
  ldlibpathflag         => '-L',
  ldpaths               => ['c:/usr/lib','C:/JAVA11/LIB','c:/usr/lib/mt','c:/usr/lib','C:/home/Prima/auto/Prima'],
  ldlibs                => ['socket','m','bsd','libperl.lib','prigraph.lib','Prima'],
  ldlibext              =>'',
  inline                => 'inline',
  perl                  => 'C:/USR/BIN/perl58.exe',
  dl_load_flags         => 0,
);

1;
