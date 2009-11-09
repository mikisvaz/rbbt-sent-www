class Normalize < Application
  include CacheHelper

  def index
    cache("normalize") do
      @datasets = Job::datasets
      @title = "Sent: Gene Name Translator"
      @found = @missing = []
      @head_title = "Gene Name Translator"
      render
    end
  end
  
  def post
    @title = "Sent: Gene Name Translator"
    @head_title = "Gene Name Translator"
    @datasets = Job::datasets
    genes = params[:genes].split(/\n/)
    ids   = params[:ids].split(/\n/)
    org   = params[:org]

    translations = Job::Info::normalize(org,genes)

    @found   = ids + translations.select{|p| p && p.length == 1}.collect{|p| p.first}
    @missing = genes.zip(translations).select{|p| p[1].nil? || p[1].length != 1}.collect{|p| p[0]}
    @org     = org

    render :template => 'normalize/index'
  end
end
