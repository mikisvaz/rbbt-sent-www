class Result < Application
  include CacheHelper

  def wait(name, factors)
    job = Job.new(name, factors)
    @messages = [
            "Translate genes",
            "Build gene term matrix",
            "Build dictionary",
            "Build metadocument",
            "Perform NMF",
            "Analyze results",
    ]
    @times = Hash[*@messages.zip([
            '1 min.',
            '1 min.',
            '5-10 min.',
            '5-10 min.',
            '3-5 min.',
            '1 min.',
    ]).flatten]
   

    info = job.info
    if ['queued', 'prepared'].include?  Job.status(name)
      @in_queue = true
    else

      @current = job.real_messages.select{|m| @messages.include? m.chomp}.last
      @done    = @messages.clone
      @missing = []

      while @done.any? && @done.last != @current
        @missing << @done.pop
      end

      @missing.reverse!
      @done.delete(@current)
      @done    = @done.select{|msg| msg !~/gene term matrix/} if (info[:fine] || info[:custom])
      @done    = @done.select{|msg| msg !~/dictionary|metadocument/} unless (info[:fine] || info[:custom])
      @missing = @missing.select{|msg| msg !~/dictionary|metadocument/} unless (info[:fine] || info[:custom])

      @done    = @done.select{|msg| msg !~/Translate/}       if info[:custom]
      @missing = @missing.select{|msg| msg !~/Translate/}    if info[:custom]

    end
    @factors = job.factors

    @title = "[#{job.status}] #{ job.name }"
    @head_title = "Job #{ job.name } Is Being Processed"
    render :template =>  'result/wait'
  end

  def show_main(name, factors)
    @job = Job.new(name, factors)
    cache(name, @job.fingerprint) do
      @job.update
      @title = "Sent: #{ name }"
      @head_title = "Results for Job: #{ name }"
      render :template => 'result/main'
    end
  end

  def main
    name, @factors  = params['job'].split(/=/).values_at(0,1)

    begin

      @factors ||= Job::best(name)
      @factors ||= Job::info(name)[:factors]
      @factors = @factors.to_i if @factors

      return wait(name, nil) if @factors.nil?

      if Job.range(name).any? && !Job.range(name).include?(@factors)
        raise "The job has not explored the value #{@factors} for the number of factors."
      end

      case
      when Job.done(name).include?(@factors)
        show_main(name, @factors)
      when Job.failed(name).include?(@factors)
        raise Job.messages(name).last
      when Job.in_process(name) == @factors 
        wait(name, @factors)
      else 
        if Job::error?(name)
          raise Job::messages(name).last
        else 
          wait(name, @factors)
        end
      end

    rescue Job::JobNotFound
      @title = "Job #{ name } Error"
      @error = "Job #{ name } not found"
      Merb.logger.error("-----------")
      Merb.logger.error($!.message)
      Merb.logger.error($!.backtrace.join("\n"))
      render :template => 'result/error'
    rescue Exception
      @title = "Job #{ name } Error"
      @error = $!.message 
      Merb.logger.error("-----------")
      Merb.logger.error($!.message)
      Merb.logger.error($!.backtrace.join("\n"))
      render :template => 'result/error'
    end
  end

  def show_group(name, factors, group)
    @job = Job.new(name, factors)
    cache(name,{:fingerprint =>  @job.fingerprint, :group => group}) do
      @job.update
      if group == 0
        @title = "Sent: [Job Details] #{ name }"
        @head_title = "Job Details: #{ name }"
        render :template => 'result/complete_details'
      else
        @title = "Sent: [#{ group }] #{ name }"
        @head_title = "Group: #{ group }. Job: #{ name }"
        @group = @job.groups[group - 1]
        render :template => 'result/group_details'
      end
    end
  end

  def group
    name, @factors  = params['job'].split(/=/).values_at(0,1)
    group = params[:group].to_i

    begin

      @factors ||= Job::best(name)
      @factors ||= Job::info(name)[:factors]
      @factors = @factors.to_i if @factors

      return wait(name, nil) if @factors.nil?

      if !Job.range(name).include? @factors
        raise "The job has not explored the value #{@factors} for the number of factors."
      end

      case
      when Job.done(name).include?(@factors)
        show_group(name, @factors,group)
      when Job.failed(name).include?(@factors)
        raise Job.error(name)
      when Job.in_process(name) == @factors 
        wait(name, @factors)
      else 
        case
        when Job::success?(name)
          show_group(name, @factors,group)
        when Job::error?(name)
          raise Job::messages(name).last
        else 
          wait(name, @factors)
        end
      end

    rescue Job::JobNotFound
      @title = "Job #{ name } Error"
      @error = "Job #{ name } not found"
      Merb.logger.error("-----------")
      Merb.logger.error($!.message)
      Merb.logger.error($!.backtrace.join("\n"))
      render :template => 'result/error'
    rescue Exception
      @title = "Job #{ name } Error"
      @error = $!.message 
      Merb.logger.error("-----------")
      Merb.logger.error($!.message)
      Merb.logger.error($!.backtrace.join("\n"))
      render :template => 'result/error'
    end
  end


  def show_literature(name, factors, group, gene, words, page, size)
    @job = Job.new(name, factors)
    cache(name,{
      :fingerprint =>  @job.fingerprint, 
      :group => group,
      :gene => gene,
      :words => words,
      :page => page,
      :size => size}) do

      @query = words || []
      @job.update

      index_first = (page - 1) * size
      index_last  = page * size

      @page = page

      if group == 0
        @pages =  @job.group_ranks.length / size + 1
        index_last  = [@job.group_ranks.length, index_last].min
        @head_title = "Literature. Job: #{ @job.name}"
        if @page > @pages
          @error = "Page out of range"
          render :error
        else
          @title = "Sent: [Literature] #{ @job.name}"
          @ranks = @job.group_ranks.sort{|a,b| b[1].max <=> a[1].max}[index_first .. index_last] 
          render :complete_literature
        end
      else
        if gene == 'all'
          @group = @job.groups[group.to_i - 1]
          @pages =  @group.ranks(words).length / size + 1
          index_last  = [@group.ranks(words).length,index_last].min
          @head_title = "Literature. Group: #{group}. Job: #{ @job.name}"
          if @page > @pages
            @error = "Page out of range"
            render :error
          else
            @title = "Sent: [Literature: Group #{group}] #{ @job.name}"
            @ranks = @group.ranks(words).sort{|a,b| b[1] <=> a[1]}[index_first .. index_last] 
            render :group_literature
          end
        else
          @group = @job.groups[group.to_i - 1]
          @gene = gene
          pmids = @job.associations([gene])[gene]
          all_ranks = @group.ranks(words).select{|pmid, value| pmids.include? pmid}
          index_last  = [all_ranks.length,index_last].min
          @pages =   all_ranks.length  / size + 1
          gene_name =  @group.genes_info[@gene][:name]
          @head_title = "Literature. Gene: #{gene_name}. #{ @job.name}"
          if @page > @pages
            @error = "Page out of range"
            render :error
          else
            @title = "Sent: [Literature: Gene #{gene_name}] #{ @job.name}"
            @ranks = all_ranks.sort{|a,b| b[1] <=> a[1]}[index_first .. index_last] 
            index_last  = [@ranks.length,index_last].min
            render :gene_literature
          end
        end
      end
    end
  end

  def literature
    name, @factors  = params['job'].split(/=/).values_at(0,1)
    group = params[:group].to_i
    words = params[:words]
    words = words.scan(/\w+/) if words
    gene = params[:gene]
    page = params[:page] || 1
    size = params[:size] || 20
    page = page.to_i
    size = size.to_i



    begin

      @factors ||= Job::best(name)
      @factors ||= Job::info(name)[:factors]
      @factors = @factors.to_i if @factors

      return wait(name, nil) if @factors.nil?

      if !Job.range(name).include? @factors
        raise "The job has not explored the value #{@factors} for the number of factors."
      end

      case
      when Job.done(name).include?(@factors)
        show_literature(name, @factors,group, gene, words, page, size)
      when Job.failed(name).include?(@factors)
        raise Job.error(name)
      when Job.in_process(name) == @factors 
        wait(name, @factors)
      else 
        case
        when Job::success?(name)
          show_literature(name, @factors,group, gene, words, page, size)
        when Job::error?(name)
          raise Job::messages(name).last
        else 
          wait(name, @factors)
        end
      end

    rescue Job::JobNotFound
      @title = "Job #{ name } Error"
      @error = "Job #{ name } not found"
      Merb.logger.error("-----------")
      Merb.logger.error($!.message)
      Merb.logger.error($!.backtrace.join("\n"))
      render :template => 'result/error'
    rescue Exception
      @title = "Job #{ name } Error"
      @error = $!.message 
      Merb.logger.error("-----------")
      Merb.logger.error($!.message)
      Merb.logger.error($!.backtrace.join("\n"))
      render :template => 'result/error'
    end
  end

end

