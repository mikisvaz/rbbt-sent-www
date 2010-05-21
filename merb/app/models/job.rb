require 'lib/helpers'

class Job

  DATA_DIR    = File.join(Sent.workdir, 'merb', 'data')
  RESULTS_DIR = File.join(Merb.root, 'public', 'results')


  RETRIES = 1

  FileUtils.mkdir_p DATA_DIR    unless File.exists?(DATA_DIR)
  FileUtils.mkdir_p RESULTS_DIR unless File.exists?(RESULTS_DIR)

  class JobNotFound < Exception; end
  class InProgress < Exception; end
  
  include CacheHelper


  module Info
    class << self
      include CacheHelper
    end


    @@lexicon = {}
    def self.lexicon(org)
      @@lexicon[org] ||= Organism.lexicon(org, :flatten => true)
    end


    def self.goid2name(go)
      GO::id2name(go)
    end

    def self.gene_url(org, gene)
      case org.to_s
      when 'Sc':  return "http://db.yeastgenome.org/cgi-bin/locus.pl?dbid=" + gene 
      when 'Ca':  return "http://www.candidagenome.org/cgi-bin/locus.pl?dbid=" + gene 
      when 'Rn':  return "http://rgd.mcw.edu/tools/genes/genes_view.cgi?id=" + gene.sub(/RGD:/,'') 
      when 'Mm':  return "http://www.informatics.jax.org/javawi2/servlet/WIFetch?page=markerDetail&id=" + gene
      when 'Sp':  return "http://www.genedb.org/genedb/Search?organism=pombe&isid=true&name=" + gene
      when 'Hs':  return "http://www.ncbi.nlm.nih.gov/sites/entrez?Db=gene&Cmd=ShowDetailView&ordinalpos=1&itool=EntrezSystem2.PEntrez.Gene.Gene_ResultsPanel.Gene_RVDocSum&TermToSearch=" + gene
      when 'Ce':  return "http://www.wormbase.org/db/gene/gene?name=#{gene};class=Gene"
      when 'At':  return "http://www.arabidopsis.org/servlets/Search?type=general&search_action=detail&method=1&show_obsolete=F&name=#{gene}&sub_type=gene&SEARCH_EXACT=4&SEARCH_CONTAINS=1"
      else return nil
      end
    end

    @@goterms = {}
    def self.goterms(org, gene)
      @@goterms[org] ||= Organism.goterms(org)
      @@goterms[org][gene]
    end

    def self.pmid_info(pmid)
      article = PubMed.get_article(pmid)
      url = "http://www.ncbi.nlm.nih.gov/pubmed/#{pmid}"
      [url,article.title || "", article.abstract || ""]
    end

    @@indexes={}
    def self.normalize(org, genes)
      index = @@indexes[org]
      if index.nil?
        index = Organism.norm(org)
        @@indexes[org] = index
      end
      genes.collect{|gene|
        index.resolve(gene, "", :threshold => -5)
      }
    end

  end

  module Genecodis
    def self.driver
      wsdl_url = File.join('http://genecodis.dacya.ucm.es/static/wsdl/genecodisWS.wsdl')
      driver = SOAP::WSDLDriverFactory.new(wsdl_url).create_rpc_driver
      driver
    end

    def self.analysis(org, list)

      gc_org = org
      return [] if gc_org.nil?

      job_id = driver.analyze(gc_org,2,0,-1,3,list,%w(GO_Biological_Process ),[])  


      while (stat = driver.status(job_id)) == 1
        sleep 1
      end

      if stat < 0
        return []
      else
        xml = XmlSimple.xml_in( driver.resultsxml(job_id) )

        
        return [] if xml["Result"].nil? || xml["Result"].empty?

        goterms = xml["Result"].sort{|a,b|
          a["Hyp_c"].first.to_f <=> b["Hyp_c"].first.to_f
        }.select{|res|
          res["Hyp_c"].first.to_f < 0.01
        }.collect{|res|
          {
            :support       => res["S"].first,
            :total_support => res["TS"].first,
            :pvalue        => res["Hyp_c"].first.to_f,
            :go_terms      => res["Items"].first["Item"],
            :genes         => res["Genes"].first["Gene"].collect{|g| g['content']},
          }
        }

        goterms
      end
    rescue
      puts $!.message
      puts $!.backtrace
      []
    end
  end


  module WS
    class << self
      include CacheHelper
    end

    def self.driver
      wsdl_url = File.join(Sent.workdir, 'webservice', 'wsdl', 'SentWS.wsdl')
      SOAP::WSDLDriverFactory.new(wsdl_url).create_rpc_driver
    end

    def self.datasets
      marshal_cache('datasets') do
        drv = driver
        drv.datasets.collect{|ds| [ds, YAML.load(drv.description(ds))] }.sort{|a,b| a[1]["Name"] <=> b[1]["Name"]}
      end
    end

    def self.associations(name)
      marshal_cache("associations_#{name}") do
        drv = driver
        associations = {}
        drv.associations(name).each{|l|
          values = l.chomp.split(/\t/)
          gene = values.shift
          associations[gene] ||= []
          associations[gene] += values
        }
        associations
      end
    end

    def self.stems(name)
      marshal_cache("stems_#{name}") do
        drv = driver
        stems = {}
        drv.stems(name).each{|l|
          values = l.chomp.split(/\t/)
          stems[values.shift] = values
        }
        stems
      end
    end

    def self.ranks(name, words)
      marshal_cache("ranks_#{name}_#{words.sort.inspect}") do
        drv = driver
        ranks = {}
        drv.search_literature(name, words).each{|l|
          pmid, score = l.chomp.split(/\t/)
          ranks[pmid] = score
        }
        ranks
      end
    end


    def self.analyze(org, list, factors, name = "")
      begin
        driver.analyze(org, list, factors, name)
      rescue
        puts $!.message
        puts $!.backtrace.join("\n")
        nil
      end
    end

    def self.fine_grained(org, list, factors, name = "")
      begin
        driver.fine_grained(org, list, factors, name)
      rescue
        nil
      end
    end


    def self.custom(associations, factors, name = "")
      begin
        driver.custom(associations, factors , name)
      rescue
        nil
      end
    end

    def self.refactor(job, factors, name = "")
      begin
        driver.refactor(job, factors, name)
      rescue
        nil
      end
    end


    def self.build_index(job, name = "")
      begin
        driver.clear_index(job)
        driver.build_index(job, name)
      rescue
        nil
      end
    end



    def self.info(name)
      YAML::load(driver.info(name))
    end

    def self.messages(name)
      driver.messages(name)
    end

    def self.status(name)
      driver.status(name)
    end

    def self.done?(name)
      driver.done(name)
    end

    def self.success?(name)
      driver.status(name) == 'done'
    end

    def self.aborted?(name)
      driver.aborted(name) == 'done'
    end

    def self.reset(name)
      driver.reset(name) 
    end


    def self.error?(name)
        %w(error aborted).include? driver.status(name) 
    end

    def self.process(name)
      drv = driver
      factors = info(name)[:factors]

      # Avoid errors on race conditions
      return if ! drv.done(name)
      results = drv.results(name)
      [
          "#{name}.#{factors}.summary",
          "#{name}.#{factors}.cophenetic",
          "#{name}.#{factors}.merged.profiles",
          "#{name}.#{factors}.merged.features",
          "#{name}.#{factors}.jpg",
          "#{name}.#{factors}.hard.jpg",
          "#{name}.#{factors}.profiles",
          "#{name}.#{factors}.features",
      ].zip(results){|p|
        file =  File.join(RESULTS_DIR, p[0])
        if !File.exists?(file)
          data = Base64.decode64(drv.result(p[1]))
          Open.write(file, data)
        end
      }
    end

  end

  def self.method_missing(method, *args)
    Job::WS::send(method, *args)
  end

  def self.data(name)
    filename = File.join(DATA_DIR, "job.#{name}.marshal")
    if File.exist? filename
      return Marshal::load(File.open(filename))
    else
      begin
        info = WS::info(name)
        data = {:range => [info[:factors]] || []} 
        save(name, data)
        return data
      rescue
        raise JobNotFound, "Job with name #{ name } not found."
      end
    end
  end

  def self.save(name, data)
    filename = File.join(DATA_DIR, "job.#{name}.marshal")
    fout = File.open(filename,'w')
    fout.write(Marshal::dump(data))
    fout.close
    nil
  end

  def self.range(name)
    data(name)[:range].collect{|f| f.to_i}.sort.uniq
  end

  def self.single?(name)
    range(name).length == 1
  end

  def self.done(name)
    Dir.glob(File.join(RESULTS_DIR, "#{name}.*.summary")).collect{|f| f.match(/\.(\d+)\.summary/)[1].to_i}
  end

  def self.failed(name)
    errors =  data(name)[:errors] || {}
    errors.select{|k,v| v.length > RETRIES}.collect{|p| p[0]}
  end

  def self.failed_literature(name)
    data = data(name)
    return false unless data[:errors] && data[:errors][:literature]
    data[:errors][:literature].length > RETRIES
  end

  def self.process_literature_error(name)
    data = data(name)
    job = data[:literature_job]
    data[:errors][:literature] ||= []
    if !data[:errors][:literature].include? job
      data[:errors][:literature] << job
    end
    save(name,data)
  end

  def self.process_error(name, factors = nil)
    data = data(name)
    info = info(name)
    if factors.nil?
      if data[:refactor]
        factors = WS::info(data[:refactor][:name])[:factors]
      else
        factors = info[:factors]
      end
    end
    job = info[:refactor] || info[:recluster] || name
    data[:errors] ||= {}
    data[:errors][factors] ||= []
    if !data[:errors][factors].include? job
      data[:errors][factors] << job
    end
    save(name,data)
  end

  def self.cophenetics(name)
    coph = {}
    Dir.glob(File.join(RESULTS_DIR, "#{name}.*.cophenetic")).each{|f| 
      factors = f.match(/\.(\d+)\.cophenetic/)[1].to_i
      c = File.open(f).read.to_f
      coph[factors] = c
    }
    coph
  end

  def self.best(name)
    coph = cophenetics(name)
    if coph.keys.any?
      coph.sort{|a,b| b[1] <=> a[1]}.first[0]
    else
      nil
    end
  end

  def self.clean(name, factors)
    FileUtils.rm(Dir.glob(File.join(RESULTS_DIR, "#{name}.#{factors}.*")))
  end

  def self.missing(name)
    range(name) - done(name) - failed(name)
  end

  def self.missing?(name)
    missing(name).any?
  end

  def self.scheduled_literature?(name)
    data(name)[:literature] == false
  end
  def self.has_literature?(name)
    data(name)[:literature] ||= info(name)[:literature_done]
  end

  def self.literature_job(name)
    data(name)[:literature_job]
  end

  def self.schedule_refactor(name, factors)
    factors = factors.to_i if String === factors
    factors = [factors] if Integer === factors
    data = data(name)
    done = done(name)

    factors.collect{|f| f.to_i}.each{|f|
      data[:range] << f unless data[:range].include? f
      data[:errors].delete(f) if data[:errors]
      clean(name, f) if done.include? f
    }
    save(name, data)

    refactor(name, factors.collect{|f| f.to_i}.sort.first)

    nil
  end

  def self.schedule_literature(name)
    data = data(name)
    data[:literature] = false
    save(name, data)
  end

  def self.genes(name)
    info = info(name)
    if info[:custom] 
      info[:associations].select{|l| l =~ /\t/}.collect{|l| l.split(/\t/).first.strip}.compact.uniq
    else
      info[:translated].compact.collect{|n| n.strip}
    end
  end


  def self.translations(name)
    info = info(name)
    genes = genes(name)
    if info[:custom]
      Hash[*genes.collect{|n| n.strip if n}.zip(genes.collect{|n| n.strip}).flatten]
    else
      Hash[*info[:translated].collect{|n| n.strip if n}.zip(info[:list].collect{|n| n.strip}).flatten]
    end
  end

  def self.process(name)
    data = data(name)
    raise  InProgress unless WS::done?(name)
    data.delete(:refactor) if data[:refactor]
    data.delete(:recluster) if data[:recluster]
    save(name, data)
    WS::process(name)
    Open.write(File.join(RESULTS_DIR,"#{ name }.#{ info(name)[:factors] }.translations"), translations(name).collect{|k,v| "#{v}\t#{k}"}.join("\n"))
  end

  def self.build_index(name)
    job = WS::build_index(name)
    data = data(name)
    data[:literature] = false
    data[:literature_job] = job
    save(name,data)
  end

  def self.update_literature_status(name)
    
    data = data(name)
    return if data[:literature]

    info = WS::info(name)
    if info[:literature_done]
      data[:literature] = true
    elsif WS::error?(data[:literature_job])
      data.delete([:literature_job])
      process_literature_error(name)
    end

    save(name, data)
  end


  def self.refactor(name, factors)
    factors = factors.to_i
    refactor = WS::refactor(name, factors)
    data = data(name)
    data[:refactor] = {:name => refactor, :factors => factors} if refactor
    data[:range] << factors unless data[:range].include? factors
    save(name,data)
  end

  def self.in_process(name)
    data = data(name)
    if data[:refactor]
      data[:refactor][:factors]
    else
      nil
    end
  end

  def self.analyze(org, list, range, name = "")
    job = WS::analyze(org, list, range.sort.first, name)
    if job
      data = {:range => range}
      save(job, data)
    end
    job
  end

  def self.custom(associations, range, name = "")
    job = WS::custom(associations, range.sort.first, name )
    if job
      data = {:range => range}
      save(job, data)
    end
    job
  end

  def self.fine_grained(org, list, range, name = "")
    job = WS::fine_grained(org, list, range.first, name )
    if job
      data = {:range => range}
      save(job, data)
    end
    job
  end


  def self.update(name)
    data = data(name)
    if missing(name).any? || in_process(name)
      if in_process(name)
        if WS::success?(data[:refactor][:name])
          process(name)
        elsif WS::error?(data[:refactor][:name]) || WS::aborted?(data[:refactor][:name])
          reset(name)
          d = data
          d.delete(:refactor)
          d.delete(:recluster)
          save(name,d)
          process_error(name)
        end
      elsif success?(name)
        begin
          process(name)
        rescue Exception
          puts $!.message
        end
      elsif error?(name) || aborted?(name)
        process_error(name)
      end
    end
    update_literature_status(name) if data[:literature_job] && !data[:literature]
  end

  # Instance
  attr_reader :name, :data_store, :factors
  def initialize(name, factors = nil)
    @name = name
    @factors = factors || Job::info(name)[:factors]
    @data_store = {}
  end

  def fingerprint
    fingerprint = info
    fingerprint[:actual_factors] = factors
    fingerprint
  end


  def method_missing(method, *args)
    data_store[method] ||= Job.send(method, *([self.name] + args))
  end

  def [](key)
    info[key.to_sym]
  end

  def complete_name
    "#{name}=#{factors}"
  end

  def cophenetic
    Job::cophenetics(name)[@factors]
  end


  def missing_genes
    if info[:custom]
      return []
    else
      data_store[:missing_genes] ||= info[:list].zip(info[:translated]).select{|p| p[1] !~ /\w/}.collect{|p| p[0]}
    end
    data_store[:missing_genes]
  end

  def synonyms(genes=nil)

    if info[:custom]
      codes = info[:associations].each{|l| l.chomp.split(/\t/).first}
      data_store[:synonyms] ||= Hash[*codes.zip(codes).flatten]
    else
      data_store[:synonyms] ||= Job::Info::lexicon(info[:org]).slice(self.genes)
    end

    if genes
      data_store[:synonyms].slice(genes) 
    else
      data_store[:synonyms]
    end
  end

  def associations(genes = nil)
    data_store[:associations] ||= Job.associations(self.name).slice(self.genes)

    if genes
      data_store[:associations].slice(genes)
    else
      data_store[:associations]
    end
  end

  def rare_genes
    genes - associations.keys
  end

  def stems(words = nil)
    data_store[:stems] ||= Job.stems(self.name)

    if genes
      data_store[:stems].slice(words)
    else
      data_store[:stems]
    end
  end


  def articles(genes = nil)
    if genes
      associations.slice(genes).values.flatten.compact.uniq
    else
      data_store[:articles] = associations.values.flatten.compact.uniq
      data_store[:articles]
    end
  end

  def goterms(genes = nil)
    genes ||= self.genes
    data_store["goterms_" + genes.sort.inspect] ||= Genecodis::analysis(info[:org], genes)
  end

  def groups_info
    @factors ||= info[:factors]
    update
    raise InProgress if factors.nil? or !done.include?(factors)

    data_store[:groups_info] ||= YAML::load(File.open(File.join(RESULTS_DIR, "#{name}.#{factors}.summary")))
  end

  def ranks(words, articles = nil)
    raise InProgress unless has_literature?
    data_store["ranks_#{words.sort.inspect}"] ||= Job::WS::ranks(self.name, words)

    if articles
      data_store["ranks_#{words.sort.inspect}"].slice(articles) 
    else
      data_store["ranks_#{words.sort.inspect}"] 
    end
  end


  def group_ranks
    raise "To many groups to provide useful information. Please use group specific literature exploration" if groups.length > 10
    
    if data_store[:group_ranks].nil?
      ranks = {}
      groups.each_with_index{|group,i|
        group.ranks(nil, :max => 1000).each{|pmid, score|
          ranks[pmid] ||= Array.new(groups.length, 0)
          ranks[pmid][i] = score  
        }
      }
      max_per_group = Array.new(size=groups.length, obj = 0)
      ranks.each{|k,values|   
        values.collect!{|v| v.to_f}
        values.each_with_index{|v,i|
          max_per_group[i] = v if v > max_per_group[i] 
        }
      }
      ranks.each{|k, values| values.collect_with_index!{|v,i| v.to_f/max_per_group[i]}}
      data_store[:group_ranks] = ranks
    end

    data_store[:group_ranks]
  end


  def genes_info(genes = nil)
    data[:genes_info] ||= marshal_cache("genes_info#{Digest::MD5.hexdigest(self.genes.sort.inspect)}_#{info[:org]}") do
      genes_info = {}
      self.genes.each{|gene|
        gene_info = {}
        gene_info[:name]     = translations[gene]
        if info[:org] 
          gene_info[:url]      = Info::gene_url(info[:org], gene)
          gene_info[:goterms]  = Info::goterms(info[:org], gene) || [] 
        else
          gene_info[:goterms]  = [] 
          gene_info[:url]      = nil
        end
        gene_info[:synonyms] = []
        gene_info[:articles] = []

        genes_info[gene] = gene_info
      }

      associations.each{|gene, pmids|
        genes_info[gene][:articles] = pmids || [] if genes_info.keys.include? gene
      }

      synonyms.each{|gene, list|
        genes_info[gene][:synonyms] = list || [] if genes_info.keys.include? gene
      }
      
      genes_info
    end

    if has_literature?
      self.groups.each{|group|
        group.genes.each{|gene|
          data[:genes_info][gene][:literature] = "/literature/#{ complete_name }/#{group.number}/#{ gene }"
        }
      }
    end

    if genes
      data[:genes_info].slice(genes)
    else
      data[:genes_info]
    end
  end

  def real_status
    if data[:refactor]
      Job::WS::status(data[:refactor][:name])
    else
      status
    end
  end

  def real_messages
    if data[:refactor]
      messages + Job::WS::messages(data[:refactor][:name])
    else
      messages
    end
  end

  def groups
    if @groups.nil?
      @groups = []
      groups_info.length.times{|i|
        @groups << Group.new(self, i)
      }
    end
    @groups
  end

end



