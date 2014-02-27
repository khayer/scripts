#!/usr/bin/env ruby
require 'optparse'
require 'logger'

# 2014/2/27 Katharina Hayer

$logger = Logger.new(STDERR)


# Initialize logger
def setup_logger(loglevel)
  case loglevel
  when "debug"
    $logger.level = Logger::DEBUG
  when "warn"
    $logger.level = Logger::WARN
  when "info"
    $logger.level = Logger::INFO
  else
    $logger.level = Logger::ERROR
  end
end

def setup_options(args)
  options = {:cut_off =>  5, :log_level => "info"}

  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options] genes_file blastx_master compare1 [compare2...]"
    #opts.banner = "Usage: compare_fpkm_values [options] fpkm_values.txt"
    opts.separator ""

    opts.on("-c", "--cut_off [CUT_OFF]",
      :REQUIRED, Float,
      "Number of reads cut off? DEFAULT: 5") do |a|
      options[:cut_off] = a
    end

    #opts.on("-p", "--pre_fix [PRE_FIX]",
    #  :REQUIRED,String,
    #  "Prefix for SNP. DEFAULT: syrian_") do |pre_fix|
    #  options[:pre_fix] = pre_fix
    #end

    opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
      options[:log_level] = "info"
    end

    opts.on("-d", "--debug", "Run in debug mode") do |v|
      options[:log_level] = "debug"
    end
  end

  args = ["-h"] if args.length == 0
  opt_parser.parse!(args)
  raise "Please specify the sam files" if args.length == 0
  options
end

def read_blast(blastx_master,compare_files,genes)
  results = {}
  genes.each_pair do |id,name|
    blast_master_id = `grep "#{id}" #{blastx_master}`
    blast_master_id.chomp!
    res = blast_master_id.split("\n").map {|e| e.split("\t")}[0]
    next unless res
    results[name] = []
    results[name] << res
    compare_files.each do |filename|
      blast_id = `grep "#{id}" #{filename} | grep "#{res[1]}"`
      if blast_id
        blast_id.chomp!
        res2 = blast_id.split("\n").map {|e| e.split("\t")}[0]
        results[name] << res2
      end
    end
    #puts results
    #STDIN.gets
  end
  results
end

def read_genes_file(genes_file)
  genes = {}
  File.open(genes_file).each do |line|
    line.chomp!
    name, id = line.split(" ")
    genes[id] = name
  end
  genes
end

def run(argv)
  options = setup_options(argv)
  setup_logger(options[:log_level])
  $logger.debug(options)
  $logger.debug(argv)

  # genes_file blastx_master compare1 [compare2...]
  genes_file = ARGV[0]
  blastx_master = ARGV[1]
  compare_files = ARGV[2..-1]

  genes = read_genes_file(genes_file)
  results = read_blast(blastx_master,compare_files,genes)

  results.each_pair do |name, res|
    puts name
    res.each do |r|
      puts r.join("\t") if r
    end
  end
end

if __FILE__ == $0
  run(ARGV)
end