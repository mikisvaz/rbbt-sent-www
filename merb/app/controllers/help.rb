class Help < Application
  include CacheHelper

  def help
    cache("help") do
      render
    end
  end
  
  def glossary
    cache("glossary") do
      @datasets = Job::datasets
      render
    end
  end

  def ws
    cache("Web Service") do
      render
    end
  end


  def guide
    cache("guide") do
      render
    end
  end


end
