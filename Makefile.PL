

use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'CurlingCalendar',
  VERSION      => '1.0',
  AUTHOR       => 'Andreas Marienborg <omega@palle.net>',
  EXE_FILES    => ['script/curling_calendar'],
  PREREQ_PM    => {
      'Mojolicious' => '6.38',
      'Path::Tiny'  => '0.01',
      'HTTP::Tiny'  => '0.01',
      'Encode'      => '0.01',
      'Data::ICal'  => '0.01',
      'Data::ICal::DateTime' => '0.1',
  },
  test         => {TESTS => 't/*.t'}
);
