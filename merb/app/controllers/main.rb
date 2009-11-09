class Main < Application
  include CacheHelper

  def index
    cache("index") do
      @datasets = Job::datasets
      @title = "SENT: Semantic Features in Text"
      @head_title = @title
      render
    end
  end

  def post
    org        = params[:org]
    factors    = params[:factors]
    ids        = params[:ids].split(/[\s,;]+/).uniq if params[:ids]
    fine       = params[:fine_grained]
    name       = params[:name].gsub(/[^\w]/,'_')
    email      = params[:email]
    literature = params[:literature]

    begin 

      raise "No factors specified." if factors == ""   
      raise "Factor list format unrecognized" unless factors =~ /^(\s*\d+|\d+\s*\-\s*\d+\s*,?)+/
      factor_list = parse_factors(factors) 

      raise "No factors specified." if factor_list.empty?

      raise "The minimum value for the number of factors is 2." if factor_list.min < 2 
      raise "The largest value for the number of factors is 32." if factor_list.max > 32  

      raise "The number of different values for the number of factors must not be larger than 8." if factor_list.length > 8  


      if params[:file] && params[:file][:tempfile]
        ids = params[:file][:tempfile].read.collect{|l| l.chomp.split(/[\s,;]+/)}.flatten.compact.collect{|e| e.strip}
      end


      if org == 'custom'       
        raise "No Association File Specified." unless params[:associations] && params[:associations][:tempfile] 

        associations = params[:associations][:tempfile].read.chomp

        name = Job::custom(associations,factor_list, name)
      else
        if fine
          name = Job::fine_grained(org, ids, factor_list, name)
        else
          name = Job::analyze(org, ids, factor_list, name)
        end
      end

      if name.nil?
        raise "Job was not processed ok, check the paremeters."
      end

      if literature
        Job.schedule_literature(name)
      end
      Mailer.instance.add(name, email) if email && email =~ /@/                     

      ip = request.env['HTTP_X_FORWARDED_FOR'] || request.env['REMOTE_ADDR']
      JobLog.log(ip, email, name)

      redirect "/#{ name }"
    rescue Exception
      @title = "SENT: Semantic Features in Text"
      @head_title = @title
      @error = $!.message
      Merb.logger.error("-----------")
      Merb.logger.error($!.message)
      Merb.logger.error($!.backtrace.join("\n"))
      render :template => 'main/error'
    end
  end

end
