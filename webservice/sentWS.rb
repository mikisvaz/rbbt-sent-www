require 'simplews/jobs'
require 'simplews/rake'
require 'sent'
require 'sent/main'
require 'rbbt/sources/organism'
require 'yaml'

class SentWS < SimpleWS::Jobs
  class ArgumentError < Exception; end
  class NotDone < Exception; end

  #{{{ Analysis
  


  helper :translate  do |org, list|
    index = Organism.id_index(org)
    list.collect{|id|
      index[id]
    }
  end

  helper :analysisdir do
    File.join(Sent.datadir, "analysis/")
  end 

  helper :rakefile do
    File.join(analysisdir, 'Rakefile')
  end

  desc "Produce semantic features for organism genes"
  param_desc :org     => "Organism",
             :factors => "Number of factors to use (one semantic feature for factor by default)",
             :list    => "List of gene ids"
  task :analyze, %w(org list factors), 
    {:org => :string,  :factors => :integer, :list => :array},
    [
      "summary/{JOB}",
      "summary/{JOB}.cophenetic",
      "summary/{JOB}.merged.profiles",
      "summary/{JOB}.merged.features",
      "summary/{JOB}.jpg",
      "summary/{JOB}.hard.jpg",
      "NMF/{JOB}.profiles",
      "NMF/{JOB}.features",
  ] do |org, list, factors|
    
    Process.setpriority(Process::PRIO_PROCESS, 0, 10)

    raise SentWS::ArgumentError, "Organism '#{ org }' not supported" unless File.exists? File.join(analysisdir, "metadoc/#{ org }")
    raise SentWS::ArgumentError, "Number of factors should be larger than 1" if factors <= 1

    begin
      info :original => list

      step(:translate, "Translate genes")
      translated = translate(org,list)

      raise SentWS::ArgumentError, "No genes were identified" if translated.compact.empty?
      raise SentWS::ArgumentError, "No more than 1024 genes allowed" if translated.compact.uniq.length > 1024
      raise SentWS::ArgumentError, "Number of genes must exceed number of factors" if factors > translated.compact.uniq.length
      raise SentWS::ArgumentError, "Not enough genes were identified" if translated.compact.length < factors

      $org     = org
      $genes   = translated.compact
      $factors = factors 
      $metadoc_dir = File.join(analysisdir, 'metadoc')

      rake rakefile
    rescue Sent::ProcessAbortedError
      abort
    end
  end

  desc "Produce fine grained semantic features for organism genes"
  param_desc :org     => "Organism",
             :factors => "Number of factors to use (one semantic feature for factor by default)",
             :list    => "List of gene ids"
  task :fine_grained, %w(org list factors), 
    {:org => :string,  :factors => :integer, :list => :array},
    [
      "summary/{JOB}",
      "summary/{JOB}.cophenetic",
      "summary/{JOB}.merged.profiles",
      "summary/{JOB}.merged.features",
      "summary/{JOB}.jpg",
      "summary/{JOB}.hard.jpg",
      "NMF/{JOB}.profiles",
      "NMF/{JOB}.features",
  ] do |org, list, factors|
    Process.setpriority(Process::PRIO_PROCESS, 0, 10)

    raise SentWS::ArgumentError, "Organism '#{ org }' not supported" unless File.exists? File.join(analysisdir, "metadoc/#{ org }")
    raise SentWS::ArgumentError, "Number of factors should be larger than 1" if factors <= 1

    info :fine => true
    info :original => list

    begin
      step(:translate, "Translate Genes")
      translated = translate(org,list)

      raise SentWS::ArgumentError, "No genes were identified" if translated.compact.empty?
      raise SentWS::ArgumentError, "No more than 1024 genes allowed" if translated.compact.uniq.length > 1024
      raise SentWS::ArgumentError, "Number of genes must exceed number of factors" if factors > translated.compact.uniq.length
      raise SentWS::ArgumentError, "Not enough genes were identified" if translated.compact.length < factors

      associations = Open.to_hash(File.join(analysisdir, 'associations', org), :exclude => Proc.new{|l| ! translated.include? l.match(/^(.*)\t/)[1] })

      FileUtils.touch File.join(workdir, 'mentions', job_name)
      File.open(File.join(workdir, 'associations', job_name), 'w') do |f|
        f.puts associations.collect{|code, values| "%s\t%s" % [code, values * "|"] } * "\n"
      end

      $org          = org
      $metadoc_name = job_name
      $genes        = translated.compact
      $factors      = factors 

      rake rakefile
    rescue Sent::ProcessAbortedError
      abort
    end
  end

  desc "Produce semantic features for arbitrary entities associated with pubmed ids"
  param_desc :associations     => "Association file: <ENTITY_CODE>\t<PMID>|<PMID>|<PMID>..>",
             :factors => "Number of factors to use (one semantic feature for factor by default)"
  task :custom, %w(associations factors), 
    {  :factors => :integer, :associations => :string},
    [
      "summary/{JOB}",
      "summary/{JOB}.cophenetic",
      "summary/{JOB}.merged.profiles",
      "summary/{JOB}.merged.features",
      "summary/{JOB}.jpg",
      "summary/{JOB}.hard.jpg",
      "NMF/{JOB}.profiles",
      "NMF/{JOB}.features",
  ] do |associations, factors|
    Process.setpriority(Process::PRIO_PROCESS, 0, 10)

    raise SentWS::ArgumentError, "Number of factors should be larger than 1" if factors <= 1

    info :custom => true, :associations  => associations

    entities  = associations.collect{|l| l.match(/^(.*?)\t/)[1] }.compact
    raise SentWS::ArgumentError, "No more than 1024 entities allowed" if entities.length > 1024
    raise SentWS::ArgumentError, "Number of factors should be larger than 1" if factors <= 1
    raise SentWS::ArgumentError, "Number of genes must exceed number of factors" if factors > entities.length

    info :original => entities

    begin

      FileUtils.touch File.join(workdir, 'mentions', job_name)
      File.open(File.join(workdir, 'associations', job_name), 'w') do |f|
        f.puts associations
      end

      $genes        = entities
      $org          = 'custom'
      $metadoc_name = job_name
      $factors      = factors 

      rake rakefile
    rescue Sent::ProcessAbortedError
      abort
    end
  end

  desc "For a given job, change the number of semantic features without performing a new factorization"
  param_desc :analysis_job => "Id for the job to recluster",
            :clusters     => "Number of semantic features to extract"
  task :recluster, %w(analysis_job clusters), {:analysis_job => :string, :clusters => :integer}, [] do |analysis_job, clusters|
    Process.setpriority(Process::PRIO_PROCESS, 0, 10)

    begin
      self.info :name       => job_name,
        :job                => analysis_job,
        :clusters           => clusters

      raise SentWS::NotDone, "Job must have the factorization finished." unless File.exist?(path("NMF/#{analysis_job}.profiles"))

      state = Scheduler.job_info(analysis_job)
      raise SentWS::ArgumentError, "Job must not have other modifier jobs." if state[:recluster] || state[:refactor] 

      state[:info][:recluster] = job_name
      state[:status]           = :recluster
      state[:info][:clusters]  = clusters
      Scheduler::Job.save(analysis_job, state)

      removed_files = Dir.glob(File.join(workdir, 'summary', analysis_job + '*'))
      FileUtils.rm(removed_files)

      $clusters      = clusters
      rake rakefile, File.join(workdir, 'summary', analysis_job)

      state = Scheduler.job_info(analysis_job)
      state[:info].delete(:recluster)
      state[:status] = :done
      Scheduler::Job.save(analysis_job, state)
    rescue Sent::ProcessAbortedError
      abort
    end
  end

  desc "For a given job, refactor the data to form a new set of semantic features"
  param_desc :analysis_job => "Id for the job to recluster",
             :factors      => "Number of semantic features to extract"
  task :refactor, %w(analysis_job factors), {:analysis_job => :string, :factors => :integer}, [] do |analysis_job, factors|
    Process.setpriority(Process::PRIO_PROCESS, 0, 10)

    begin
      self.info :name => job_name,
                :job  => analysis_job

      raise SentWS::NotDone, "Job must have the factorization finished." unless File.exist?(path("NMF/#{analysis_job}.profiles"))

      state = Scheduler.job_info(analysis_job)
      raise SentWS::ArgumentError, "Job must not have other modifier jobs." if state[:recluster] || state[:refactor] 

      state[:info][:recluster] = job_name
      state[:status]           = :refactor
      state[:info][:factors]   = factors
      state[:info][:clusters]  = factors
      Scheduler::Job.save(analysis_job, state)

      removed_files = Dir.glob(File.join(workdir, 'NMF', analysis_job + '*'))
      FileUtils.rm(removed_files)

      $factors = factors
      rake rakefile, File.join(workdir, 'summary', analysis_job)

      state = Scheduler.job_info(analysis_job)
      state[:info].delete(:refactor)
      state[:status] = :done
      Scheduler::Job.save(analysis_job, state)

    rescue Sent::ProcessAbortedError
      abort
    end
  end

  desc "Index abstracts of articles associated to the genes"
  param_desc :analysis_job => "Id for the job to recluster"
  task :build_index, %w(analysis_job), {:analysis_job => :string}, [] do |analysis_job|
    Process.setpriority(Process::PRIO_PROCESS, 0, 10)

    articles  = []
    step(:associations, "Loading Associations")

    state = Scheduler.job_info(analysis_job)
    state[:info][:literature] = job_name
    Scheduler::Job.save(analysis_job, state)

    if state[:info][:custom] 
      $associations_file = File.join(workdir, 'associations', analysis_job)
    else
      $org               = state[:info][:organism]
      $associations_dir  = File.join(analysisdir, 'associations')
    end
    
    $genes             = state[:info][:genes]

    rake rakefile, File.join(workdir, 'literature', analysis_job)

    state[:info][:literature_done] = true
    Scheduler::Job.save(analysis_job, state)
  end

  def initialize(*args)
    super(*args)
   
    @analysisdir = File.join(Sent.datadir, 'analysis')

    desc "List available datasets"
    param_desc :return => 'Array of dataset codes'
    serve :datasets, %w(), :return => :array do 
      Dir.glob(File.join(@analysisdir, 'associations/') + '*.description').collect{|f|
        File.basename(f).sub(/.description/,'')
      }
    end

    desc "Return the description for a dataset"
    param_desc :dataset => "Dataset for which to return the description",
               :return   => "Dataset description"
    serve :description, %w(dataset), :dataset => :string, :return => :string do |dataset|
      begin
        File.open(File.join(Sent.datadir, "analysis/associations/#{ dataset }.description")).read
      rescue Exception
      end
    end

    desc "Return the word stems for the terms in the job"
    param_desc :job      => "Job id",
               :return   => "Dataset description"
    serve :stems, %w(job), :job => :string, :return => :string do |job|
      info = Scheduler.job_info(job)[:info]
      if info[:fine] || info[:custom]
        File.open(File.join(workdir, "dictionary/#{job}.stems")).read
      else
        File.open(File.join(@analysisdir, "dictionary/#{info[:organism]}.stems")).read
      end
    end

    desc "Return the gene articles associations used in the analysis"
    param_desc :job    => "Job ID",
               :return => "Association file: <GENE>TAB<PMID>|<PMID>|<PMID>|..."
    serve :associations, %w(job), :job => :string, :return => :string do |job|
      info = Scheduler.job_info(job)[:info]
      if info[:fine] || info[:custom]
        File.open(File.join(workdir, "associations/#{job}")).read
      else
        genes = info[:genes]
        File.open(File.join(@analysisdir, "associations/#{info[:organism]}")).
        select{|l| gene, pimd = l.chomp.split(/\t/); genes.include?(gene)}.
          compact.uniq.join("\n")
      end
    end

    desc "Query literature index for the job"
    param_desc :job    => "Job ID",
               :words  => "List of words to query",
               :return => "Article scores: <PMID>TAB<SCORE>"
    serve :search_literature, %w(job words), :job => :string, :words => :array, :return => :string do |job, words|
      info = Scheduler.job_info(job)[:info]
      raise SentWS::NotDone, "No Literature Index" unless info[:literature_done]
      ranks = Sent.search_index(words, Scheduler::Job::path("literature/#{ job }", job))
      ranks.collect{|p| p.join("\t")}.join("\n")
    end

    desc "Reset the article index"
    param_desc :job    => "Job ID"
    serve :clear_index, %w(job), :job => :string, :return => false do |job|
      info = Scheduler.job_info(job)

      FileUtils.rm_r(File.join(workdir, "literature/#{name}")) if File.exist?(File.join(workdir, "literature/#{job}"))
      info[:info].delete(:literature)
      info[:info].delete(:literature_done)

      Scheduler::Job.save(job, info)
    end

    desc "Reset all modifier jobs for a given analysis job"
    param_desc :job    => "Job ID"
    serve :reset, %w(job), :job => :string, :return => false do |job|
      info = Scheduler.job_info(job)

      if info[:status] == :recluster
        Scheduler.abort(info[:info][:recluster])
        info.delete(:recluster)
        if Scheduler.job_info(info[:info][:recluster])[:status] == :done
          info[:status]    = 'done'
        else
          info[:status]    = 'aborted'
        end

        info[:messages] << Scheduler.job_info(info[:info][:recluster])[:messages].last if info[:status] == :error
      end

      if info[:status] == :refactor
        Scheduler.abort(info[:info][:refactor])
        info.delete(:refactor)
        if Scheduler.job_info(info[:info][:refactor])[:status] == :done
          info[:status]    = 'done'
        else
          info[:status]    = 'aborted'
        end

        info[:messages] << Scheduler.job_info(info[:info][:refactor])[:messages].last if info[:status] == :error
      end

      Scheduler::Job.save(job, info)
    end
  end


  class Scheduler::Job
    alias_method :old_step, :step
    def step(status, message=nil)
      logger.debug "#{Time.now} => [#{ @name }]: #{ status }. #{ message }"
      old_step(status, message)
    end 
  end

end

if __FILE__  == $0
  host = @host || `hostname`.chomp.strip + '.' +  `hostname -d`.chomp.strip
  port = @port || '8182'

  puts "Starting Server in #{ host }:#{ port }"

  job_dir = File.join(Sent.workdir, 'webservice', 'jobs')
  FileUtils.mkdir_p job_dir unless File.exist? job_dir
  server = SentWS.new("Sent", "Sent Web Server",host, port, job_dir)

  wsdl_dir = File.join(Sent.workdir, 'webservice', 'wsdl')
  FileUtils.mkdir_p wsdl_dir unless File.exist? wsdl_dir
  Open.write(File.join(wsdl_dir, 'SentWS.wsdl'), server.wsdl)

  documentation_dir = File.join(Sent.workdir, 'webservice', 'documentation')
  FileUtils.mkdir_p documentation_dir unless File.exist? documentation_dir
  Open.write(File.join(documentation_dir, 'SentWS.documentation'), server.documentation)

  log_dir = File.join(Sent.workdir, 'webservice', 'log')
  FileUtils.mkdir_p log_dir unless File.exist? log_dir
  server.logtofile(File.join(log_dir, 'SentWS.log'))

  trap('INT') { server.abort_jobs; server.shutdown }
  server.start

end

