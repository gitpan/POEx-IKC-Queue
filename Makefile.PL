#!/usr/bin/perl

use 5.008;
use ExtUtils::MakeMaker;

WriteMakefile(
    dist              => {COMPRESS=>'gzip -9f', EXT=>'gz'},
    NAME              => 'POEx::IKC::Queue',
    VERSION_FROM      => 'lib/POEx/IKC/Queue.pm', # finds $VERSION
    PREREQ_PM         => {
            'POE'                     => 1.280,
            'POE::Component::IKC'     => 0.2200,
            'POEx::IKC::Connection'   => 0,
            'POEx::URI'               => 0.03,
            'POE::Session::PlainCall' => 0.02
        }, 
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/POEx/IKC/Queue.pm', # retrieve abstract from module
       AUTHOR         => 'Philip Gwyn <gwyn -at- cpan.org', 
       LICENSE        => 'perl'
      ) : ()),
);
