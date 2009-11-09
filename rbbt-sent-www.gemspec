# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{rbbt-sent-www}
  s.version = "0.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Miguel Vazquez"]
  s.date = %q{2009-11-02}
  s.description = %q{This package contains a SOAP web server and a merb application.}
  s.email = %q{miguel.vazquez@fdi.ucm.es}
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    "lib/rbbt-sent-www.rb"
  ]
  s.homepage = %q{http://github.com/mikisvaz/rbbt-sent-www}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{SENT online interface}
  s.test_files = [
    "test/helper.rb",
     "test/test_rbbt-sent-www.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<MARQ>, [">= 0"])
      s.add_runtime_dependency(%q<rbbt>, [">= 0"])
      s.add_runtime_dependency(%q<merb>, [">= 0"])
      s.add_runtime_dependency(%q<simplews>, [">= 0"])
      s.add_runtime_dependency(%q<rmail>, [">= 0"])
      s.add_runtime_dependency(%q<RedCloth>, [">= 0"])
      s.add_runtime_dependency(%q<rand>, [">= 0"])
      s.add_runtime_dependency(%q<xml-simple>, [">= 0"])
    else
      s.add_dependency(%q<MARQ>, [">= 0"])
      s.add_dependency(%q<rbbt>, [">= 0"])
      s.add_dependency(%q<merb>, [">= 0"])
      s.add_dependency(%q<simplews>, [">= 0"])
      s.add_dependency(%q<rmail>, [">= 0"])
      s.add_dependency(%q<RedCloth>, [">= 0"])
      s.add_dependency(%q<rand>, [">= 0"])
      s.add_dependency(%q<xml-simple>, [">= 0"])
    end
  else
    s.add_dependency(%q<MARQ>, [">= 0"])
    s.add_dependency(%q<rbbt>, [">= 0"])
    s.add_dependency(%q<merb>, [">= 0"])
    s.add_dependency(%q<simplews>, [">= 0"])
    s.add_dependency(%q<rmail>, [">= 0"])
    s.add_dependency(%q<RedCloth>, [">= 0"])
    s.add_dependency(%q<rand>, [">= 0"])
    s.add_dependency(%q<xml-simple>, [">= 0"])
  end
end
