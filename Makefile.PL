

use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'CurlingCalendar',
  VERSION      => '1.0',
  AUTHOR       => 'Andreas Marienborg <omega@palle.net>',
  EXE_FILES    => ['script/curling_calendar'],
  PREREQ_PM    => {
      'Mojolicious' => '6.80',
      'Path::Tiny'  => '0.1',
      'HTTP::Tiny'  => '0.1',
      'Encode'      => '0.1',
      'Data::ICal'  => '0.1',
      'Data::ICal::DateTime' => '0.1',
  },
  test         => {TESTS => 't/*.t'}
);
