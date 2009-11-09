# == Synopsis
#
# sent: Launches an analysis job to the SENT Web Service
#
# == Usage
#
# sent [OPTIONS]
#
# -h, --help:
#    show help
#
# --list, -l
#   Lists the available databases
#
# --genes file, -g file:
#   File containing the gene identifiers. For an example use:
#
#   http://sent.dacya.ucm.es/examples/human.txt
#
# --organism code, -o code:
#   Code of the database to use:
#
# --factors number, -f number:
#   Factors to use in the analysis
#
# --name name:
#   Name for the analysis job, used to query the results in the web.
#   If its not specified a random name will be assigned
#


require 'soap/wsdlDriver'
require 'base64'
require 'getoptlong'
require 'rdoc/usage'
require 'fileutils'

WSDL_FILE= 'http://sent.dacya.ucm.es/wsdl/SentWS.wsdl'
def driver
  $driver ||= SOAP::WSDLDriverFactory.new(WSDL_FILE).create_rpc_driver
  $driver
end


options = {}
opts = GetoptLong.new(
  [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
  [ '--list', '-l', GetoptLong::NO_ARGUMENT ],
  [ '--genes', '-g', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--organism', '-o', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--factors', '-f', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--name', GetoptLong::REQUIRED_ARGUMENT ]
).each{|opt, value| options[opt] = value}

if options['--list']
  puts driver.datasets()
  exit
end

if options['--genes'].nil? || options['--organism'].nil? || options['--factors'].nil? || options['--help']
  RDoc::usage
  exit -1
end

genes = File.open(options['--genes']).read.split(/[,\s]+/s)
factors = options['--factors'].to_i
organism = options['--organism']
name = options['--name'] || ""

realname = driver.analyze(organism, genes, factors, name)

puts "Analysis started"
puts "Job status and results can also be queried at"
puts "http://sent.dacya.ucm.es/" + realname

puts ""
puts "Waiting to finish"

while !driver.done(realname)
  sleep 10
end

puts ""
puts "Job finished with status: " + driver.status(realname)

puts ""
puts "Gathering results to directory #{realname}/"
FileUtils.mkdir(realname) unless File.exist?(realname)  

results = driver.results(name)
[
"#{realname}/summary.yaml",
"#{realname}/cophenetic",
"#{realname}/merged.profiles",
"#{realname}/merged.features",
"#{realname}/heatmap.jpg",
"#{realname}/heatmap.hard.jpg",
"#{realname}/profiles",
"#{realname}/features",
].zip(results){|p|
  file = p[0]
  data = driver.result(p[1])
  data = Base64.decode64(data) if file =~ /\.jpg$/

  fout = File.open(file, 'w')
  fout.write data
  fout.close
}



