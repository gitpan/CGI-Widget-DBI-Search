use ExtUtils::MakeMaker;

WriteMakefile(
  NAME => "CGI::Widget::DBI::Search",
  VERSION_FROM => "lib/CGI/Widget/DBI/Search.pm",
  'dist' => { COMPRESS=>"gzip", SUFFIX=>"gz" }
);
