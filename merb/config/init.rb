# Go to http://wiki.merbivore.com/pages/init-rb
 
require 'config/dependencies.rb'
 
use_orm :datamapper
use_test :rspec
use_template_engine :haml
 
require 'merb-haml'
require 'merb-cache'
require 'sent'
require 'yaml'
require 'rbbt/util/open'
require 'rbbt/sources/organism'
require 'rbbt/sources/go'
require 'rbbt/sources/pubmed'
require 'xmlsimple'
require 'digest/md5'
require 'digest/sha2'
require 'rmail'
require 'net/smtp'    
require 'sass'    
require 'soap/wsdlDriver'

log_dir = File.join(Sent.workdir, 'merb', 'log')
FileUtils.mkdir_p log_dir unless File.exists? log_dir


Merb::Config.use do |c|
  c[:use_mutex] = false
  c[:session_store] = 'cookie'  # can also be 'memory', 'memcache', 'container', 'datamapper
  
  # cookie session store configuration
  c[:session_secret_key]  = 'bb1ab9154b55916ef514cf94e74b549753603d9c'  # required for cookie session store
  c[:session_id_key] = '_sent_session_id' # cookie session id key, defaults to "_session_id"
end
 
Merb::BootLoader.before_app_loads do
  require 'lib/helpers'
  # This will get executed after dependencies have been loaded but before your app's classes have loaded.
end
 
Merb::BootLoader.after_app_loads do
  # This will get executed after your app's classes have been loaded.
  #

  CacheHelper.reset

  Thread.new{
    while true do
      begin
        Mailer.instance.process
        Batch::process
      rescue
        puts $!.message
      ensure
        sleep 60
      end
    end
  }


end
