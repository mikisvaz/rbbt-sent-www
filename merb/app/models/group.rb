class Group
  attr_reader :job, :number, :words, :genes, :data_store
  def initialize(job, number)
    @job = job
    @number = number
    info = job.groups_info[number]
    @words = info[:words]
    @genes = info[:genes]
    @data_store = {}
  end

  def method_missing(method, *args)
    data_store[method] ||= job.send(method, *([self.genes] + args))
  end

  def number
    @number + 1
  end

  def stems
    job.stems(words)
  end

  def ranks(words = nil, options = {})
    words ||= self.words
    max = options[:max]
    if max
      Hash[*job.ranks(words, articles).sort{|a,b| b[1] <=> a[1]}[0..max].flatten]
    else
      job.ranks(words, articles)
    end
  end

end

