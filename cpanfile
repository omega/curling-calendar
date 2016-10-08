requires      'Mojolicious' , '6.38';
requires      'Mojolicious::Plugin::CHI', '0.01';
requires      'Path::Tiny'  , '0.01';
requires      'HTTP::Tiny'  , '0.01';
requires      'Encode'      , '0.01';
requires      'Data::ICal'  , '0.01';
requires      'Data::ICal::DateTime' , '0.1';
requires      'DateTime::Format::Strptime',   '0.01';
requires      'DateTime::Format::ISO8601',   '0.01';
requires      'Moo', '0.01';

on 'test' => sub {
    requires 'Test::More', '0.96';
};

