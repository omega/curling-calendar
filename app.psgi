#!/usr/bin/env perl

use Plack::Builder;

builder {
    require './script/curling_calendar';
};


