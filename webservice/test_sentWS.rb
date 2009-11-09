require File.join(File.dirname(__FILE__),'./sentWS')
require 'test/unit'

require 'rbbt/util/tmpfile'

class TestSentWS < Test::Unit::TestCase


  def setup
    server = SentWS.new("SentWS", "Semantic Features in Text", 'localhost', '1984','tmp-SentWS/')

    Thread.new do
      server.start
    end
  end

  def test_server

    require 'simplews'
    driver = SimpleWS.get_driver('http://localhost:1984', "SentWS")

    if File.exists?(File.join(Sent.datadir, 'analysis/associations/sgd.description'))
      assert(driver.description('sgd') =~ /Saccharomyces/)
    end
    
    ds = Dir.glob(File.join(Sent.datadir, 'analysis/associations/') + '*.description').collect{|f|
      File.basename(f).sub(/.description/,'')
    }

    assert(driver.datasets == ds) 


    # Test simple job
    name = driver.analyze('sgd', %w(S000000003 S000000004 S000000013 S000000019 S000000022 S000000024 S000000065 S000000099),2,"test")
    while !driver.done(name)
      puts "[#{ name }]: " + driver.messages(name).last
      sleep 5
    end
    assert(driver.status(name) == 'done')
    assert(YAML::load(driver.info(name))[:factors] == 2 )

    # Test stems
    stems = driver.stems(name)
    assert(stems.split(/\n/).any?)

    # Test associations
    assert(driver.associations(name) =~ /S\d+\t\d+/)

    # Test recluster
    driver.recluster(name, 3, 'recluster')
    assert !driver.done(name)
    while !driver.done(name)
      puts "[#{ name }]: " + driver.messages(name).last
      sleep 5
    end
    assert(YAML::load(driver.info(name))[:factors] == 2 )
    assert(YAML::load(driver.info(name))[:clusters] == 3 )
    assert(driver.status(name) == 'done')

    # Test refactor
    driver.refactor(name, 4, 'refactor')
    assert !driver.done(name)
    while !driver.done(name)
      puts "[#{ name }]: " + driver.messages(name).last
      sleep 5
    end
    assert(YAML::load(driver.info(name))[:factors] == 4 )
    assert(YAML::load(driver.info(name))[:clusters] == 4 )
    assert(driver.status(name) == 'done')


    # Run literature analysis on job
    literature_job = driver.literature(name, 'literature')
    while !driver.done(literature_job)
      puts "[#{ name }]: " + driver.messages(name).last
      sleep 5
    end

    # Test fine grained job
    name = driver.fine_grained('sgd', %w(S000000003 S000000004 S000000013 S000000019 S000000022 S000000024 S000000065 S000000099),2,2,"fine")
    while !driver.done(name)
      puts "[#{ name }]: " + driver.messages(name).last
      sleep 2
    end
    assert(driver.status(name) == 'done')

    # Test custom query
    associations = PubMed.query("Human Breast Cancer").collect{|l| pmid = l.chomp; "#{ pmid }\t#{ pmid }"}[1..1000].join("\n")
    name = driver.custom(associations,2,2,"fine")
    while !driver.done(name)
      p driver.messages(name).last
      sleep 2
    end
    assert(driver.status(name) == 'done')



  end



end

