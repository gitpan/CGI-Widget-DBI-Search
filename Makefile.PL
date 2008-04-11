use ExtUtils::MakeMaker;

WriteMakefile(
  NAME => "CGI::Widget::DBI::Search",
  VERSION_FROM => "lib/CGI/Widget/DBI/Search.pm",
  PREREQ_PM => { Test::Unit => 0 },
  'dist' => { COMPRESS=>"gzip", SUFFIX=>"gz" }
);
