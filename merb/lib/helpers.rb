require 'sent'

module JobLog
  
  LOG_DIR = File.join(Sent.workdir, 'merb', 'log')
  LOG_FILE = File.join(LOG_DIR,'jobs.log')

  FileUtils.touch LOG_FILE

  def self.log(ip, email, job)
    email = "NO EMAIL" unless email && email =~ /./
    message = "#{Time.now}: #{ ip } (#{email}) => #{ job }"
    File.open(LOG_FILE, 'a').puts message
  end


end

module CacheHelper
  CACHE_DIR = File.join(Sent.workdir, 'merb', 'cache')
  FileUtils.mkdir(CACHE_DIR) unless File.exist?(CACHE_DIR)
  def self.reset
    FileUtils.rm Dir.glob(CACHE_DIR + '/*')
  end

  def cache(name, key = [], &block)
    if Merb::Cache[:tmp_cache].exists?(name, key)
      Merb::Cache[:tmp_cache].read(name, key)
    else
      page = block.call
      Merb::Cache[:tmp_cache].write(name, page, key)
      page
    end
  end

  def marshal_cache(key)
    Marshal::load( cache(key) do
      Marshal::dump(yield)
    end)
  end


  def clean(name)
    FileUtils.rm Dir.glob(CACHE_DIR + "/#{ name }*")
  end

  Merb::Cache.setup do
    register(:tmp_cache, Merb::Cache::FileStore, :dir => CACHE_DIR) 
  end

  reset

end

module Enumerable
  def collect_with_index!
    idx = 0
    collect!{|elm| elm = yield(elm, idx); idx = idx + 1; elm}
  end
end

class Hash
  def slice(list)
    copy = {}
    ( list & self.keys).each{|k|
      copy[k] = self[k]
    }
    copy
  end
end

def parse_factors(factors)
  factors.split(/,/).collect{|f| 
    f.strip
    if f =~/(\d+)\s*\-\s*(\d+)/
      ($1.to_i..$2.to_i).to_a
    else
      f.strip
    end
  }.flatten.collect{|v| v.to_i}
end

require 'singleton'

DATA_DIR = File.join(Sent.workdir, 'merb', 'data')

module Batch
  FileUtils.mkdir(DATA_DIR) unless File.exist?(DATA_DIR)

  def self.process
    jobs = Dir.glob(DATA_DIR + "/job.*.marshal").each{|f|
      begin
        job_name = f.match(/#{DATA_DIR}\/job.(.*).marshal/)[1]
        job = Job.new(job_name)
        job.update

        if job.missing?
          if job.done? && !job.in_process
            factors = job.missing.sort[0]
            job.refactor factors
          end
        end

        if job.scheduled_literature? && job.literature_job.nil? && ['done', 'refactor', 'recluster'].include?(job.status) && !job.failed_literature
          job.build_index
        end
      rescue Exception
        puts $!.message
      end


    }
  end
end

class Mailer
  include Singleton
  FileUtils.mkdir(DATA_DIR) unless File.exist?(DATA_DIR)

  HOST = 'hoop.esi.ucm.es'

  FROM = "noreply@#{HOST}"
  SMTP = 'ucsmtp.ucm.es'

  FILE = File.join(DATA_DIR,"mails.marshal")
  def initialize
    if !File.exist?(FILE)
      Open.write(FILE, Marshal::dump({}))
    end
  end

  def send_mail(to, subject, body)
    Merb.logger.info("Sending to  #{ to }")

    message = RMail::Message.new
    message.header['To'] = to
    message.header['From'] = FROM
    message.header['Subject'] = subject
    main = RMail::Message.new
    main.body = body

    message.add_part(main)

    Net::SMTP.start(SMTP,25) do |smtp|
      smtp.send_message message.to_s,  FROM, to
    end
  end

  def process
    mails.each{|id,email|
      job = Job.new(id)
      if job.done?

        case job.status
        when 'done':
          subject = "SENT [Success] #{ id }"
          body = <<-EOF
Dear Sent user:

Your job has finished successfully. You can view the results in the following URL:

        http://#{HOST}/#{ id }

Note: Do not reply to this email, it is automatically generated
            EOF
          send_mail(email, subject, body)
        when 'error':
          subject = "SENT [Error] #{ id }"
          body = <<-EOF
Dear Sent user:

Your job has finished with an error status. You can view the error message in the following URL:

        http://#{HOST}/#{ id }

Note: Do not reply to this email, it is automatically generated
            EOF
          send_mail(email, subject, body)
        when 'aborted':
          subject = "SENT [Aborted] #{ id }"
          body = <<-EOF
Dear Sent user:

Your job has been aborted. You can view the error message in the following URL:

        http://#{HOST}/#{ id }

Note: Do not reply to this email, it is automatically generated
            EOF
          send_mail(email, subject, body)
        end

        delete(id)
      end
    }
  end

  def add(job, email)
    mails = Marshal::load(File.open(FILE))
    mails[job] = email
    Open.write(FILE,Marshal::dump(mails))
  end

  def delete(job)
    mails = Marshal::load(File.open(FILE))
    mails.delete(job)
    Open.write(FILE,Marshal::dump(mails))
  end

  def mails
    Marshal::load(File.open(FILE))
  end
end

