require 'simplews/jobs'
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

  task :analyze, %w(org list factors), 
    {:org => :string,  :factors => :integer, :list => :array},
    [
      "summary/{JOB}.summary",
      "summary/{JOB}.cophenetic",
      "summary/{JOB}.merged.profiles",
      "summary/{JOB}.merged.features",
      "summary/{JOB}.jpg",
      "summary/{JOB}.hard.jpg",
      "NMF/{JOB}.profiles",
      "NMF/{JOB}.features",
    ] do |org, list, factors|
    Process.setpriority(Process::PRIO_PROCESS, 0, 10)

    STDERR.puts "Analysis: #{ job_name } Org: #{ org } Factors: #{ factors } List: #{ list.inspect }"
    raise SentWS::ArgumentError, "Organism '#{ org }' not supported" unless File.exists? File.join(analysisdir, "metadocs/#{ org }")
    raise SentWS::ArgumentError, "Number of factors should be larger than 1" if factors <= 1

    info({
      :name       => job_name,
      :org        => org,
      :factors    => factors,
      :list       => list,
    })


    begin
      step(:translate, "Translating Genes")
      translated = translate(org,list)
      raise SentWS::ArgumentError, "No genes were identified" if translated.compact.empty?
      raise SentWS::ArgumentError, "No more than 1024 genes allowed" if translated.compact.uniq.length > 1024
      raise SentWS::ArgumentError, "Number of genes must exceed number of factors" if factors > translated.compact.uniq.length
      raise SentWS::ArgumentError, "Not enough genes were identified" if translated.compact.length < factors

      info( :translated => translated)


      step(:matrix, "Preparing Matrix")
      Sent.matrix(File.join(analysisdir, "metadocs/#{ org }"), 
                  path("matrices/#{ job_name }"), 
                  translated.compact)

      step(:nmf, "Performing Factorization")
      Sent.NMF(path("matrices/#{ job_name }"),
               path("NMF/#{ job_name }"), factors)

      step(:analysis, "Analyzing Results")
      Sent.analyze(path("NMF/#{ job_name }"), 
                   path("summary/#{ job_name }"), factors)
    rescue Sent::ProcessAbortedError
      abort
    end
  end

  task :fine_grained, %w(org list factors), 
    {:org => :string,  :factors => :integer, :list => :array},
    [
      "summary/{JOB}.summary",
      "summary/{JOB}.cophenetic",
      "summary/{JOB}.merged.profiles",
      "summary/{JOB}.merged.features",
      "summary/{JOB}.jpg",
      "summary/{JOB}.hard.jpg",
      "NMF/{JOB}.profiles",
      "NMF/{JOB}.features",
    ] do |org, list, factors|
    Process.setpriority(Process::PRIO_PROCESS, 0, 10)


    STDERR.puts "Fine: #{ job_name } Org: #{ org } Factors: #{ factors } List: #{ list.inspect }"
    raise SentWS::ArgumentError, "Organism '#{ org }' not supported" unless File.exists? File.join(analysisdir, "metadocs/#{ org }")
    raise SentWS::ArgumentError, "Number of factors should be larger than 1" if factors <= 1
    raise SentWS::ArgumentError, "Number of genes must exceed number of factors" if factors > list.length

    info({
      :name       => job_name,
      :org        => org,
      :factors    => factors,
      :list       => list,
      :fine       => true,
    })


    begin
      step(:translate, "Translating Genes")
      translated = translate(org,list)
      raise SentWS::ArgumentError, "No more than 1024 genes allowed" if translated.compact.uniq.length > 1024
      raise SentWS::ArgumentError, "No genes were identified" if translated.compact.empty?
      raise SentWS::ArgumentError, "Not enough genes were identified" if translated.compact.uniq.length < factors


      info( :translated => translated)
      `grep '^\\(#{translated.join('\\|')}\\)[[:space:]]' #{ File.join(analysisdir, "associations/#{ org }") } >> #{File.join(workdir, "custom_associations/#{ job_name }")}`


      step(:metadocs, "Preparing Metadocs")
      Sent.metadocs(path("custom_associations/#{ job_name }"), 
                    path("custom_metadocs/#{ job_name }"), 0.25, 0.8, 3000); 


      step(:matrix, "Preparing Matrix")
      Sent.matrix(path("custom_metadocs/#{ job_name }"), 
                  path("matrices/#{ job_name }"))

      step(:nmf, "Performing Factorization")
      Sent.NMF(path("matrices/#{ job_name }"),
               path("NMF/#{ job_name }"), factors)

      step(:analysis, "Analyzing Results")
      Sent.analyze(path("NMF/#{ job_name }"), 
                   path("summary/#{ job_name }"), factors)

    rescue Sent::ProcessAbortedError
      abort
    end
  end




  task :custom, %w(associations factors), 
    {  :factors => :integer, :associations => :string},
    [
      "summary/{JOB}.summary",
      "summary/{JOB}.cophenetic",
      "summary/{JOB}.merged.profiles",
      "summary/{JOB}.merged.features",
      "summary/{JOB}.jpg",
      "summary/{JOB}.hard.jpg",
      "NMF/{JOB}.profiles",
      "NMF/{JOB}.features",
    ] do |associations, factors|
    Process.setpriority(Process::PRIO_PROCESS, 0, 10)

    STDERR.puts "Custom: #{ job_name } Factors: #{ factors }"

    info({
      :name         => job_name,
      :factors      =>factors,
      :custom       => true,
      :associations => associations,
    })

    num_genes  = associations.collect{|l| l.chomp.scan(/[^\s,]+/)[0] if l.match(/[^\s,]/)}.compact.uniq.length
    raise SentWS::ArgumentError, "No more than 1024 entities allowed" if num_genes > 1024
    raise SentWS::ArgumentError, "Number of factors should be larger than 1" if factors <= 1
    raise SentWS::ArgumentError, "Number of genes must exceed number of factors" if factors > num_genes

    begin

      Open.write(path("custom_associations/#{ job_name }"), associations)
      step(:metadocs, "Preparing Metadocs")
      Sent.metadocs(path("custom_associations/#{ job_name }"), 
                    path("custom_metadocs/#{ job_name }"), 0.25, 0.8, 3000); 


      step(:matrix, "Preparing Matrix")
      Sent.matrix(path("custom_metadocs/#{ job_name }"), 
                  path("matrices/#{ job_name }"))


      step(:nmf, "Performing Factorization")
      Sent.NMF(path("matrices/#{ job_name }"),
               path("NMF/#{ job_name }"), factors)

      step(:analysis, "Analyzing Results")
      Sent.analyze(path("NMF/#{ job_name }"), 
                   path("summary/#{ job_name }"), factors)

    rescue Sent::ProcessAbortedError
      abort
    end
  end

  task :recluster, %w(analysis_job clusters), {:analysis_job => :string, :clusters => :integer}, [] do |analysis_job, clusters|
    Process.setpriority(Process::PRIO_PROCESS, 0, 10)
    STDERR.puts "Recluster of job #{ analysis_job } #{clusters} : #{ job_name }"

    begin
      self.info( {
        :name       => job_name,
        :job        => analysis_job,
        :clusters   => clusters,
      })
      raise SentWS::NotDone, "Job must have the factorization finished." unless File.exist?(path("NMF/#{analysis_job}.profiles"))

      state = Scheduler.job_info(analysis_job)
      raise SentWS::ArgumentError, "Job must not have other modifier jobs." if state[:recluster] || state[:refactor] 

      state[:info][:recluster] = job_name
      state[:status] = :recluster
      state[:info][:clusters] = clusters
      Scheduler::Job.save(analysis_job, state)

      step(:analysis, "Analyzing Results")
      Sent.analyze(File.join(workdir, "NMF/#{ analysis_job }"), 
                   File.join(workdir, "summary/#{ analysis_job }"),clusters)

      state = Scheduler.job_info(analysis_job)
      state[:info].delete(:recluster)
      state[:status] = :done
      Scheduler::Job.save(analysis_job, state)
    rescue Sent::ProcessAbortedError
      abort
    end
  end

  task :refactor, %w(analysis_job factors), {:analysis_job => :string, :factors => :integer}, [] do |analysis_job, factors|
    Process.setpriority(Process::PRIO_PROCESS, 0, 10)
    STDERR.puts "Refactor of job #{ analysis_job } #{factors} : #{ job_name }"
    begin
      self.info( {
        :name       => job_name,
        :job        => analysis_job,
        :factors   => factors,
      })
      state = Scheduler.job_info(analysis_job)
      state[:info][:refactor] = job_name
      state[:info][:factors] = factors
      state[:info][:clusters] = factors
      old_status = state[:status]
      state[:status] = :refactor
      Scheduler::Job.save(analysis_job, state)

      raise SentWS::ArgumentError, "No genes were identified" if  (state[:info][:translated].nil? || state[:info][:translated].empty?) && !state[:info][:custom]
      raise SentWS::ArgumentError, "Number of genes must exceed number of factors" if (!state[:info][:custom] && factors > state[:info][:translated].uniq.length)
      raise SentWS::ArgumentError, "Job must not have other modifier jobs." if old_status == :recluster || old_status == :refactor
      raise SentWS::ArgumentError, "Number of factors should be larger than 1" if factors <= 1
      raise SentWS::NotDone, "Job must have the analysis matrix prepared." unless File.exist?(path("matrices/#{ analysis_job }"))

      step(:nmf, "Performing Factorization")
      Sent.NMF(path("matrices/#{ analysis_job }"),
               path("NMF/#{ analysis_job }"), factors)

      step(:analysis, "Analyzing Results")
      Sent.analyze(path("NMF/#{ analysis_job }"), 
                   path("summary/#{ analysis_job }"),factors)

      state = Scheduler.job_info(analysis_job)
      state[:info].delete(:refactor)
      state[:status] = :done
      Scheduler::Job.save(analysis_job, state)
    rescue Sent::ProcessAbortedError
      abort
    end
  end

  task :build_index, %w(analysis_job), {:analysis_job => :string}, [] do |analysis_job|
    Process.setpriority(Process::PRIO_PROCESS, 0, 10)

    articles  = []
    step(:associations, "Loading Associations")

    state = Scheduler.job_info(analysis_job)
    associations  = "" 
    if state[:info][:fine] || state[:info][:custom]
      file = path("custom_associations/#{analysis_job}")
      raise(SentWS::NotDone, "Job #{ analysis_job } cannot have the literature examined untils the association file is ready ") unless File.exist?(file)
      associations = File.open(file).read
    else
      raise(SentWS::NotDone, "Job #{ analysis_job } cannot have the literature examined untils genes are translated") unless state[:info][:translated]
      genes = state[:info][:translated]
      associations = File.open(File.join(analysisdir, "associations/#{state[:info][:org]}")).
        select{|l| gene, pimd = l.chomp.split(/\t/); genes.include?(gene)}.
        compact.uniq.join("\n")
    end

    state = Scheduler.job_info(analysis_job)
    state[:info][:literature] = job_name
    Scheduler::Job.save(analysis_job, state)

    associations.each{|l|
      next unless l =~ /\t/
        parts = l.chomp.split(/\t/)
      articles << parts[1]
    }

    step(:rank, "Ranking Literature")
    Sent::literature_index(articles, path("literature/#{ analysis_job }.index"))

    state = Scheduler.job_info(analysis_job)
    state[:info][:literature_done] = true
    Scheduler::Job.save(analysis_job, state)

    results(["literature/#{analysis_job}.index"])
  end

  
  class Scheduler::Job
    alias_method :old_step, :step
    def step(status, message=nil)
      puts "#{Time.now} => [#{ @name }]: #{ status }. #{ message }"
      old_step(status, message)
    end 
  end

  def initialize(*args)
    super(*args)
    
   
    @analysisdir = File.join(Sent.datadir, 'analysis')

    %w(custom_associations custom_metadocs matrices NMF summary info).each{|d|
      FileUtils.mkdir(File.join(workdir,d)) unless File.exists?(File.join(workdir,d))
    }

    serve :datasets, %w(), :return => :array do 
      Dir.glob(File.join(@analysisdir, 'associations/') + '*.description').collect{|f|
        File.basename(f).sub(/.description/,'')
      }
    end

    serve :description, %w(org), :org => :string, :return => :string do |org|
      begin
        File.open(File.join(Sent.datadir, "analysis/associations/#{ org }.description")).read
      rescue Exception
      end
    end

    serve :stems, %w(name), :name => :string, :return => :string do |name|
      info = Scheduler.job_info(name)[:info]
      if info[:fine] || info[:custom]
        File.open(File.join(workdir, "custom_metadocs/#{name}.stems")).read
      else
        File.open(File.join(@analysisdir, "metadocs/#{info[:org]}.stems")).read
      end
    end

    serve :associations, %w(name), :name => :string, :return => :string do |name|
      info = Scheduler.job_info(name)[:info]
      if info[:fine] || info[:custom]
        File.open(File.join(workdir, "custom_associations/#{name}")).read
      else
        genes = info[:translated]
        File.open(File.join(@analysisdir, "associations/#{info[:org]}")).
        select{|l| gene, pimd = l.chomp.split(/\t/); genes.include?(gene)}.
          compact.uniq.join("\n")
      end
    end

    serve :search_literature, %w(name words), :name => :string, :words => :array, :return => :string do |name, words|
      info = Scheduler.job_info(name)[:info]
      raise SentWS::NotDone, "No Literature Index" unless info[:literature_done]
      ranks = Sent.search_index(words, Scheduler::Job::path("literature/#{ name }.index", name))
      ranks.collect{|p| p.join("\t")}.join("\n")
    end

    serve :clear_index, %w(name), :name => :string do |name|
      info = Scheduler.job_info(name)

      FileUtils.rm_r(File.join(workdir, "literature/#{name}.index")) if File.exist?(File.join(workdir, "literature/#{name}.index"))
      info[:info].delete(:literature)
      info[:info].delete(:literature_done)

      Scheduler::Job.save(name, info)
    end

    serve :reset, %w(name), :name => :string do |name|
      info = Scheduler.job_info(name)

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

      Scheduler::Job.save(name, info)
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

  trap('INT') { server.abort_jobs; server.shutdown }
  server.start

end
