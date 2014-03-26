#!/usr/bin/env ruby
require 'optparse'
require 'logger'

# 2014/2/14 Katharina Hayer

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
    opts.banner = "Usage: #{$0} [options] in.gtf"
    #opts.banner = "Usage: compare_fpkm_values [options] fpkm_values.txt"
    opts.separator ""
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



def run(argv)
  options = setup_options(argv)
  setup_logger(options[:log_level])
  $logger.debug(options)
  $logger.debug(argv)

  last_gene = nil
  positions = []
  lines = []
  File.open(genes_file).each do |line|
    line.chomp?
    name = line.split("transcript_id \"")[1].split("\"")[0]
    last_gene ||= name
    if name != last_gene
      positions.sort!
      trans_line = lines[0].split("\t")
      trans_line[2] = "transcript"
      trans_line[3] = positions[0]
      trans_line[4] = positions[-1]
      puts trans_line.join("\t")
      puts lines.join("\n")
      positions = []
      lines = []
      last_gene = name
    end
    positions << line.split("\t")[3].to_i
    positions << line.split("\t")[4].to_i
    lines << line
  end
  positions.sort!
  trans_line = lines[0].split("\t")
  trans_line[2] = "transcript"
  trans_line[3] = positions[0]
  trans_line[4] = positions[-1]
  puts trans_line.join("\t")
  puts lines.join("\n")


end

if __FILE__ == $0
  run(ARGV)
end