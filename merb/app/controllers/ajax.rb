class Ajax < Application
  include CacheHelper

  def dataset_description
    Hash[*Job::datasets.flatten][params["ORG"]]["Description"]
  end
 
  def dataset_supported_ids
    Hash[*Job::datasets.flatten][params["ORG"]]["ID Format"]
  end

  def literature
    name = params[:name]
    Job.new(name).build_index
    clean(name)
    ""
  end

  def refactor
    name = params[:name]
    factors = params[:factors]
    begin
      raise "No factors specified." if factors == ""   
      raise "Factor list format unrecognized" unless factors =~ /^\s*(\d+|\d+\s*-\s*\d+)(\s*,\s*(\d+|\d+\s*-\s*\d+))*$/
      factor_list = parse_factors(factors) 
      raise "No factors specified." if factor_list.empty?
      raise "The minimum value for the number of factors is 2." if factor_list.min < 2 
      raise "The largest value for the number of factors is 32." if factor_list.max > 32  
      raise "The number of different values for the number of factors must not be larger than 8." if factor_list.length > 8  


      clean(name)
      j = Job.new(name)
      j.schedule_refactor(factor_list)
      j.update
      ""
    rescue Exception
      puts $!.message
      return ""
    end
  end

  def done_literature
    name = params[:name]
    job = Job.new(name)
    job.update
    if job.has_literature?
      clean(job.name) 
      return "true"
    else 
      return "false"
    end
  end

  def cophenetics
    name = params[:name]
    return Job.cophenetics(name).to_json
  end
  
  def done_range
    name = params[:name]
    job = Job.new(name)
    job.update
    if job.done? && !job.missing?
      clean(name)
      return 'true'
    else
      return {
        :status => job.real_status.sub(/done|error|aborted/,'queued'), 
        :current => (job.done? ? job.missing.first : job.in_process), 
      }.to_json
    end
  end
end
